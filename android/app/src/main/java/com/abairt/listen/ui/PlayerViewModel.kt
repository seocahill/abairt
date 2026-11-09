package com.abairt.listen.ui

import android.app.Application
import android.content.ComponentName
import android.os.Bundle
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import androidx.media3.session.SessionToken
import com.abairt.listen.data.ApiException
import com.abairt.listen.data.AppSettings
import com.abairt.listen.data.Line
import com.abairt.listen.graph
import com.abairt.listen.playback.PlaybackProtocol
import com.abairt.listen.playback.PlaybackProtocol.ServiceState
import com.abairt.listen.playback.PlaybackService
import com.abairt.listen.transcript.Transcript
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch

sealed interface TranscriptState {
    data object None : TranscriptState
    data object Loading : TranscriptState
    data class Ready(val transcript: Transcript) : TranscriptState
    data class Failed(val message: String) : TranscriptState
}

/** Everything the screens need to know about what is playing, apart from the position (see [PlayerViewModel.position]). */
data class PlayerUi(
    val hasMedia: Boolean = false,
    val isPlaying: Boolean = false,
    val isBuffering: Boolean = false,
    val recordingId: Long? = null,
    val title: String = "",
    val region: String? = null,
    val durationMs: Long = 0,
    val speed: Float = 1f,
    val service: ServiceState = ServiceState(),
    val transcript: TranscriptState = TranscriptState.None,
    /** Something to tell the listener once, e.g. the radio could not start. */
    val message: String? = null,
)

/**
 * The screens' view of the playback service, through a [MediaController]: the
 * same interface the lock screen and Bluetooth use. It also fetches the
 * transcript of whatever is playing, and works out which line that is.
 */
class PlayerViewModel(application: Application) : AndroidViewModel(application) {
    private val graph = application.graph
    private var controller: MediaController? = null
    private var transcriptJob: Job? = null
    private val transcriptCache = LinkedHashMap<Pair<Long, Boolean>, Transcript>()

    private val _ui = MutableStateFlow(PlayerUi())
    val ui: StateFlow<PlayerUi> = _ui.asStateFlow()

    val settings: StateFlow<AppSettings> =
        graph.settings.settings.stateIn(viewModelScope, SharingStarted.Eagerly, AppSettings())

    /** Where playback is, ticking only while someone is collecting it (so not with the screen off). */
    val position: Flow<Long> = flow {
        while (true) {
            controller?.let { emit(it.currentPosition) }
            delay(POSITION_TICK_MS)
        }
    }.distinctUntilChanged()

    private val playerListener = object : Player.Listener {
        override fun onEvents(player: Player, events: Player.Events) = refresh()
    }

    private val controllerListener = object : MediaController.Listener {
        override fun onExtrasChanged(controller: MediaController, extras: Bundle) = refresh()
    }

    init {
        connect()
        // Re-fetch the transcript when the listener changes whether to show unchecked lines.
        viewModelScope.launch {
            var shown: Boolean? = null
            settings.collect {
                if (shown != null && shown != it.showUnchecked) loadTranscript(force = true)
                shown = it.showUnchecked
            }
        }
    }

    private fun connect() {
        val app = getApplication<Application>()
        val token = SessionToken(app, ComponentName(app, PlaybackService::class.java))
        val future = MediaController.Builder(app, token).setListener(controllerListener).buildAsync()
        viewModelScope.launch {
            val connected = try {
                future.await()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _ui.update { it.copy(message = "Could not connect to the player.") }
                return@launch
            }
            controller = connected
            connected.addListener(playerListener)
            refresh()
        }
    }

    private fun refresh() {
        val c = controller ?: return
        val metadata = c.mediaMetadata
        val previousId = _ui.value.recordingId
        val id = c.currentMediaItem?.mediaId?.toLongOrNull()
        _ui.update {
            it.copy(
                hasMedia = c.mediaItemCount > 0,
                isPlaying = c.isPlaying,
                isBuffering = c.playWhenReady && c.playbackState == Player.STATE_BUFFERING,
                recordingId = id,
                title = metadata.title?.toString().orEmpty(),
                region = metadata.artist?.toString(),
                durationMs = c.duration.takeIf { d -> d != C.TIME_UNSET } ?: metadata.durationMs ?: 0L,
                speed = c.playbackParameters.speed,
                service = ServiceState.from(c.sessionExtras),
            )
        }
        if (id != previousId) loadTranscript()
    }

    private fun loadTranscript(force: Boolean = false) {
        val id = _ui.value.recordingId
        transcriptJob?.cancel()
        if (id == null) {
            _ui.update { it.copy(transcript = TranscriptState.None) }
            return
        }
        val unchecked = settings.value.showUnchecked
        val cached = transcriptCache[id to unchecked]
        if (cached != null && !force) {
            _ui.update { it.copy(transcript = TranscriptState.Ready(cached)) }
            return
        }
        _ui.update { it.copy(transcript = TranscriptState.Loading) }
        transcriptJob = viewModelScope.launch {
            val next = try {
                val transcript = Transcript(graph.api.transcript(id, includeUnchecked = unchecked).lines)
                transcriptCache[id to unchecked] = transcript
                while (transcriptCache.size > CACHED_TRANSCRIPTS) transcriptCache.remove(transcriptCache.keys.first())
                TranscriptState.Ready(transcript)
            } catch (e: ApiException) {
                TranscriptState.Failed(e.message.orEmpty())
            }
            _ui.update { it.copy(transcript = next) }
        }
    }

    fun retryTranscript() = loadTranscript(force = true)

    fun messageShown() = _ui.update { it.copy(message = null) }

    // --- Transport ---------------------------------------------------------

    fun startRadio() {
        val c = controller ?: return
        viewModelScope.launch {
            val result = c.sendCustomCommand(PlaybackProtocol.START_RADIO, Bundle.EMPTY).await()
            if (result.resultCode != SessionResult.RESULT_SUCCESS) {
                val reason = result.extras.getString(PlaybackProtocol.RESULT_MESSAGE)
                _ui.update { it.copy(message = reason ?: "The radio could not start.") }
            }
        }
    }

    fun playPause() {
        val c = controller ?: return
        when {
            c.mediaItemCount == 0 -> startRadio()
            c.isPlaying -> c.pause()
            else -> c.play()
        }
    }

    fun nextRecording() = controller?.seekToNextMediaItem()
    fun previousRecording() = controller?.seekToPreviousMediaItem()
    fun back10() = controller?.seekBack()
    fun forward10() = controller?.seekForward()

    fun seekTo(positionMs: Long, play: Boolean = false) {
        val c = controller ?: return
        c.seekTo(positionMs)
        if (play) c.play()
    }

    // The playback service follows the speed settings, so the lock-screen button and these agree.
    fun setSpeed(speed: Float) {
        viewModelScope.launch { graph.settings.update { it.withPlaybackSpeed(speed) } }
    }

    fun toggleSlow() {
        viewModelScope.launch { graph.settings.toggleSlow() }
    }

    // --- Studying a line ---------------------------------------------------

    private fun readyTranscript(): Transcript? = (_ui.value.transcript as? TranscriptState.Ready)?.transcript

    fun lineBack() {
        val c = controller ?: return
        readyTranscript()?.backTargetMs(c.currentPosition)?.let { seekTo(it, play = true) }
    }

    fun lineNext() {
        val c = controller ?: return
        readyTranscript()?.nextTargetMs(c.currentPosition)?.let { seekTo(it, play = true) }
    }

    fun playLine(line: Line) = seekTo(line.startMs, play = true)

    /** Repeats [line] until turned off (or the listener moves away from it). */
    fun toggleLoop(line: Line) {
        val c = controller ?: return
        val looping = _ui.value.service.loopStartMs == line.startMs
        val args = Bundle().apply {
            putLong(PlaybackProtocol.ARG_START_MS, if (looping) -1 else line.startMs)
            putLong(PlaybackProtocol.ARG_END_MS, if (looping) -1 else line.endMs)
        }
        viewModelScope.launch { c.sendCustomCommand(PlaybackProtocol.LOOP_LINE, args).await() }
        if (!looping) seekTo(line.startMs, play = true)
    }

    // --- Sleep -------------------------------------------------------------

    fun sleepIn(minutes: Int) = sendSleep(minutes)
    fun sleepAtEndOfRecording() = sendSleep(PlaybackProtocol.END_OF_RECORDING)
    fun cancelSleep() = sendSleep(PlaybackProtocol.CANCEL)

    private fun sendSleep(minutes: Int) {
        val c = controller ?: return
        val args = Bundle().apply { putInt(PlaybackProtocol.ARG_MINUTES, minutes) }
        viewModelScope.launch { c.sendCustomCommand(PlaybackProtocol.SLEEP_TIMER, args).await() }
    }

    // --- Settings ----------------------------------------------------------

    /** The settings as stored, rather than the defaults [settings] starts with before they load. */
    suspend fun storedSettings(): AppSettings = graph.settings.current()

    fun rememberStudyView(open: Boolean) = saveSettings { it.copy(studyView = open) }

    fun saveSettings(change: (AppSettings) -> AppSettings) {
        viewModelScope.launch { graph.settings.update(change) }
    }

    /** Null when the server accepts the token, else why not. */
    suspend fun checkConnection(candidate: AppSettings): String? {
        return try {
            graph.apiFor(candidate.connection).radioBatch(limit = 1)
            null
        } catch (e: ApiException) {
            e.message
        }
    }

    override fun onCleared() {
        controller?.removeListener(playerListener)
        controller?.release()
        controller = null
    }

    private companion object {
        const val POSITION_TICK_MS = 200L
        const val CACHED_TRANSCRIPTS = 8
    }
}
