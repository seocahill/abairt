package com.abairt.listen.playback

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.PlayerMessage
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.CommandButton
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionError
import androidx.media3.session.SessionResult
import com.abairt.listen.MainActivity
import com.abairt.listen.R
import com.abairt.listen.data.ApiException
import com.abairt.listen.graph
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.guava.future
import kotlinx.coroutines.launch

/**
 * Plays the radio. Everything that must go on with the screen off lives here,
 * not in the UI: the queue that never runs out, the sleep timer, retrying when
 * the connection drops. The system's media controls (lock screen, notification,
 * Bluetooth, headset buttons) come from the [MediaSession].
 */
@androidx.annotation.OptIn(UnstableApi::class)
class PlaybackService : MediaSessionService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val radio = RadioQueue()

    private lateinit var player: ExoPlayer
    private var session: MediaSession? = null
    private lateinit var sleepTimer: SleepTimer

    private var loadingMore: Job? = null
    private var loopMessage: PlayerMessage? = null
    private var loop: LongRange? = null
    private var errorRetries = 0

    override fun onCreate() {
        super.onCreate()
        player = buildPlayer()
        sleepTimer = SleepTimer(
            scope = scope,
            clock = { SystemClock.elapsedRealtime() },
            control = PlayerSleepControl(),
            onChange = { publishState() },
        )
        player.addListener(PlayerEvents())
        session = MediaSession.Builder(this, player)
            .setCallback(SessionCallback())
            .setSessionActivity(openAppIntent())
            .setMediaButtonPreferences(lockScreenButtons(slow = false))
            .build()
        followSpeedSettings()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    /** Swiping the app away stops the radio only if nothing is playing: in bed, it keeps going. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!player.playWhenReady || player.mediaItemCount == 0) stopSelf()
    }

    override fun onDestroy() {
        scope.cancel()
        session?.release()
        session = null
        player.release()
        super.onDestroy()
    }

    private fun buildPlayer(): ExoPlayer {
        val upstream = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent("Abairt-Android")
        val dataSource = CacheDataSource.Factory()
            .setCache(graph.audioCache)
            .setUpstreamDataSourceFactory(upstream)
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)

        return ExoPlayer.Builder(this)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSource))
            // Speech, so a call or a navigation prompt pauses it rather than talking over it.
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                    .setUsage(C.USAGE_MEDIA)
                    .build(),
                /* handleAudioFocus = */ true,
            )
            .setHandleAudioBecomingNoisy(true) // unplugging headphones pauses
            .setWakeMode(C.WAKE_MODE_NETWORK) // keep the CPU and wifi up with the screen off
            .setSeekBackIncrementMs(SKIP_MS)
            .setSeekForwardIncrementMs(SKIP_MS)
            .build()
    }

    /**
     * The two extra buttons in the notification and on the lock screen: "back 10 seconds"
     * (scanning back is what a learner does most) and slowing down a hard stretch, both without
     * unlocking the phone in the dark. They go in the overflow slot, which the system shows
     * beside previous/next recording; it ignores the *_SECONDARY slots.
     */
    private fun lockScreenButtons(slow: Boolean) = listOf(
        CommandButton.Builder(CommandButton.ICON_SKIP_BACK_10)
            .setPlayerCommand(Player.COMMAND_SEEK_BACK)
            .setDisplayName(getString(R.string.back_10))
            .setSlots(CommandButton.SLOT_OVERFLOW)
            .build(),
        CommandButton.Builder(if (slow) CommandButton.ICON_PLAYBACK_SPEED_1_0 else CommandButton.ICON_PLAYBACK_SPEED)
            .setSessionCommand(PlaybackProtocol.TOGGLE_SLOW)
            .setDisplayName(getString(if (slow) R.string.normal_speed else R.string.slow_down))
            .setSlots(CommandButton.SLOT_OVERFLOW)
            .build(),
    )

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /**
     * Speed lives in the settings, whoever changes it (the app, or the lock-screen button), and
     * holds across restarts, so bedtime listening starts slow if it ended slow.
     */
    private fun followSpeedSettings() {
        scope.launch {
            graph.settings.settings
                .map { it.playbackSpeed to it.slow }
                .distinctUntilChanged()
                .collect { (speed, slow) ->
                    player.setPlaybackParameters(player.playbackParameters.withSpeed(speed))
                    session?.setMediaButtonPreferences(lockScreenButtons(slow))
                }
        }
    }

    // --- Radio -------------------------------------------------------------

    private suspend fun startRadio(): SessionResult {
        radio.reset()
        loadingMore?.cancel()
        val batch = try {
            graph.api.radioBatch(radio.batchSize)
        } catch (e: ApiException) {
            return failure(e.message)
        }
        if (batch.isEmpty()) return failure("There are no recordings with a transcript yet.")

        radio.queued(batch.map { it.id })
        clearLoop()
        player.setMediaItems(batch.map { it.toMediaItem() })
        player.prepare()
        player.play()
        return SessionResult(SessionResult.RESULT_SUCCESS)
    }

    private fun failure(message: String?) = SessionResult(
        SessionError.ERROR_UNKNOWN,
        Bundle().apply { putString(PlaybackProtocol.RESULT_MESSAGE, message) },
    )

    /** Keeps a few recordings waiting, so the radio does not stop in the dark. Retries quietly when offline. */
    private fun loadMoreIfNeeded() {
        if (loadingMore?.isActive == true) return
        if (!radio.shouldLoadMore(player.currentMediaItemIndex, player.mediaItemCount)) return

        loadingMore = scope.launch {
            val loaded = try {
                val batch = graph.api.radioBatch(radio.batchSize, radio.excludeIds())
                radio.queued(batch.map { it.id })
                player.addMediaItems(batch.map { it.toMediaItem() })
                true
            } catch (e: ApiException) {
                false
            }
            if (!loaded) delay(RETRY_MS)
            loadingMore = null
            if (!loaded) loadMoreIfNeeded()
        }
    }

    private fun trimHistory() {
        val trim = radio.itemsToTrim(player.currentMediaItemIndex)
        if (trim > 0) player.removeMediaItems(0, trim)
    }

    // --- Looping one line --------------------------------------------------

    private fun startLoop(startMs: Long, endMs: Long) {
        clearLoop(publish = false)
        loop = startMs..endMs
        loopMessage = player.createMessage { _, _ -> player.seekTo(startMs) }
            .setLooper(Looper.getMainLooper())
            .setPosition(endMs)
            .setDeleteAfterDelivery(false)
            .send()
        publishState()
    }

    private fun clearLoop(publish: Boolean = true) {
        loopMessage?.cancel()
        loopMessage = null
        if (loop != null) {
            loop = null
            if (publish) publishState()
        }
    }

    // --- Published state ---------------------------------------------------

    private fun publishState() {
        val timer = sleepTimer.state
        val state = PlaybackProtocol.ServiceState(
            sleepEndsAt = timer.endsAtMs,
            sleepAtEndOfRecording = timer.endOfRecording,
            loopStartMs = loop?.first,
            loopEndMs = loop?.last,
        )
        session?.setSessionExtras(state.toBundle())
    }

    private inner class PlayerSleepControl : SleepTimerControl {
        override fun setVolume(volume: Float) {
            player.volume = volume
        }

        override fun pause() = player.pause()

        override fun setPauseAtEndOfRecording(enabled: Boolean) {
            player.pauseAtEndOfMediaItems = enabled
        }
    }

    private inner class PlayerEvents : Player.Listener {
        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            clearLoop()
            trimHistory()
            loadMoreIfNeeded()
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_READY) errorRetries = 0
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            if (reason == Player.PLAY_WHEN_READY_CHANGE_REASON_END_OF_MEDIA_ITEM) sleepTimer.endOfRecordingReached()
        }

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            // Seeking away from the line being looped ends the loop.
            val looping = loop ?: return
            if (reason == Player.DISCONTINUITY_REASON_SEEK && newPosition.positionMs !in looping) clearLoop()
        }

        /** A dropped connection should not end the night: retry, then skip to the next recording. */
        override fun onPlayerError(error: PlaybackException) {
            scope.launch {
                delay(RETRY_MS)
                if (++errorRetries > MAX_RETRIES && player.hasNextMediaItem()) {
                    errorRetries = 0
                    player.seekToNextMediaItem()
                }
                player.prepare()
            }
        }
    }

    private inner class SessionCallback : MediaSession.Callback {
        override fun onConnect(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
        ): MediaSession.ConnectionResult {
            val commands = MediaSession.ConnectionResult.DEFAULT_SESSION_COMMANDS.buildUpon()
                .add(PlaybackProtocol.START_RADIO)
                .add(PlaybackProtocol.SLEEP_TIMER)
                .add(PlaybackProtocol.LOOP_LINE)
                .add(PlaybackProtocol.TOGGLE_SLOW)
                .build()
            return MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
                .setAvailableSessionCommands(commands)
                .build()
        }

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: SessionCommand,
            args: Bundle,
        ): ListenableFuture<SessionResult> = when (customCommand.customAction) {
            PlaybackProtocol.START_RADIO.customAction -> scope.future { startRadio() }

            PlaybackProtocol.SLEEP_TIMER.customAction -> {
                when (val minutes = args.getInt(PlaybackProtocol.ARG_MINUTES, PlaybackProtocol.CANCEL)) {
                    PlaybackProtocol.CANCEL -> sleepTimer.cancel()
                    PlaybackProtocol.END_OF_RECORDING -> sleepTimer.startEndOfRecording()
                    else -> sleepTimer.startMinutes(minutes)
                }
                Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }

            PlaybackProtocol.LOOP_LINE.customAction -> {
                val start = args.getLong(PlaybackProtocol.ARG_START_MS, -1)
                val end = args.getLong(PlaybackProtocol.ARG_END_MS, -1)
                if (start >= 0 && end > start) startLoop(start, end) else clearLoop()
                Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }

            PlaybackProtocol.TOGGLE_SLOW.customAction -> scope.future {
                graph.settings.toggleSlow()
                SessionResult(SessionResult.RESULT_SUCCESS)
            }

            else -> Futures.immediateFuture(SessionResult(SessionError.ERROR_NOT_SUPPORTED))
        }
    }

    private companion object {
        const val SKIP_MS = 10_000L
        const val RETRY_MS = 5_000L
        const val MAX_RETRIES = 5
    }
}
