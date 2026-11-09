package com.abairt.listen.playback

import kotlin.math.max
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** What the sleep timer does to the player. */
interface SleepTimerControl {
    fun setVolume(volume: Float)
    fun pause()

    /** Pause when the current recording ends instead of starting the next. */
    fun setPauseAtEndOfRecording(enabled: Boolean)
}

/** What the timer is doing now, for showing it. */
data class SleepTimerState(
    /** When playback will stop, in the timer's clock milliseconds; null when no countdown is running. */
    val endsAtMs: Long? = null,
    val endOfRecording: Boolean = false,
) {
    val isActive: Boolean get() = endsAtMs != null || endOfRecording
}

/**
 * Stops the radio for someone falling asleep: after a number of minutes, with
 * the volume easing down over the last [fadeMs], or at the end of the
 * recording that is playing.
 */
class SleepTimer(
    private val scope: CoroutineScope,
    private val clock: () -> Long,
    private val control: SleepTimerControl,
    private val onChange: (SleepTimerState) -> Unit,
    private val fadeMs: Long = 30_000,
    private val tickMs: Long = 1_000,
) {
    private var job: Job? = null
    var state = SleepTimerState()
        private set

    fun startMinutes(minutes: Int) {
        cancel()
        val endsAt = clock() + minutes * 60_000L
        publish(SleepTimerState(endsAtMs = endsAt))
        job = scope.launch {
            while (true) {
                val remaining = endsAt - clock()
                if (remaining <= 0) break
                control.setVolume(if (remaining >= fadeMs) 1f else remaining.toFloat() / fadeMs)
                delay(minOf(tickMs, max(remaining, 1L)))
            }
            control.pause()
            control.setVolume(1f)
            publish(SleepTimerState())
        }
    }

    fun startEndOfRecording() {
        cancel()
        control.setPauseAtEndOfRecording(true)
        publish(SleepTimerState(endOfRecording = true))
    }

    /** The player paused at the end of a recording, as asked: the timer is spent. */
    fun endOfRecordingReached() {
        if (!state.endOfRecording) return
        control.setPauseAtEndOfRecording(false)
        publish(SleepTimerState())
    }

    fun cancel() {
        job?.cancel()
        job = null
        if (state.isActive) {
            control.setVolume(1f)
            control.setPauseAtEndOfRecording(false)
            publish(SleepTimerState())
        }
    }

    private fun publish(next: SleepTimerState) {
        state = next
        onChange(next)
    }
}
