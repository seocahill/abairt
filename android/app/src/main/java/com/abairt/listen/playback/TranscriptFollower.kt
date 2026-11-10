package com.abairt.listen.playback

import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import com.abairt.listen.data.ApiException
import com.abairt.listen.transcript.Transcript
import com.abairt.listen.transcript.TranscriptRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Follows the transcript of whatever is playing, with the screen off: shows
 * the line being spoken on the lock screen (through [LinePlayer]) and steps
 * back a line at a time. It wakes when the next line starts rather than
 * polling, and stops looking while paused.
 */
@UnstableApi
class TranscriptFollower(
    private val player: Player,
    private val linePlayer: LinePlayer,
    private val transcripts: TranscriptRepository,
    private val scope: CoroutineScope,
    /** Called when a transcript arrives or goes, e.g. to change the lock-screen buttons. */
    private val onTranscriptChanged: () -> Unit,
) : Player.Listener {
    /** The transcript of what is playing, once fetched; null without one. */
    var transcript: Transcript? = null
        private set

    private var includeUnchecked = true
    private var showOnLockScreen = true
    private var loading: Job? = null
    private var following: Job? = null

    fun settingsChanged(includeUnchecked: Boolean, showOnLockScreen: Boolean) {
        val reload = includeUnchecked != this.includeUnchecked
        this.includeUnchecked = includeUnchecked
        this.showOnLockScreen = showOnLockScreen
        if (reload) load() else follow()
    }

    /**
     * Restarts the line playing, or goes to the one before if it has only just
     * begun, and plays. False without a transcript, for the caller to fall back.
     */
    fun backOneLine(): Boolean {
        val target = transcript?.backTargetMs(player.currentPosition) ?: return false
        player.seekTo(target)
        player.play()
        return true
    }

    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) = load()

    override fun onIsPlayingChanged(isPlaying: Boolean) = follow()

    override fun onPositionDiscontinuity(
        oldPosition: Player.PositionInfo,
        newPosition: Player.PositionInfo,
        reason: Int,
    ) = follow()

    private fun load() {
        loading?.cancel()
        following?.cancel()
        setTranscript(null)
        val id = player.currentMediaItem?.mediaId?.toLongOrNull() ?: return

        loading = scope.launch {
            val fetched = try {
                transcripts.get(id, includeUnchecked)
            } catch (e: ApiException) {
                null // no line on the lock screen, and "back 10 seconds" instead of a line
            }
            setTranscript(fetched)
            follow()
        }
    }

    private fun setTranscript(value: Transcript?) {
        transcript = value
        linePlayer.show(null)
        onTranscriptChanged()
    }

    private fun follow() {
        following?.cancel()
        val transcript = transcript?.takeIf { showOnLockScreen }
        if (transcript == null) {
            linePlayer.show(null)
            return
        }
        following = scope.launch {
            do {
                val position = player.currentPosition
                linePlayer.show(transcript.lineAt(position))
                val wait = transcript.msUntilNextLine(position, player.playbackParameters.speed) ?: break
                delay(wait.coerceIn(MIN_WAIT_MS, MAX_WAIT_MS))
            } while (player.isPlaying)
        }
    }

    private companion object {
        /** Not sooner, so lines a few milliseconds apart do not spin. */
        const val MIN_WAIT_MS = 50L

        /** Not later, so drift (buffering, a dropped frame) is put right within a second. */
        const val MAX_WAIT_MS = 1_000L
    }
}
