package com.abairt.listen.playback

import android.os.Bundle
import androidx.media3.session.SessionCommand

/**
 * What the screen and the playback service say to each other beyond play,
 * pause and seek: custom session commands to the service, and the service's
 * state (sleep timer, line loop) published back in the session extras.
 */
object PlaybackProtocol {
    private const val PREFIX = "com.abairt.listen."

    val START_RADIO = SessionCommand(PREFIX + "START_RADIO", Bundle.EMPTY)
    val SLEEP_TIMER = SessionCommand(PREFIX + "SLEEP_TIMER", Bundle.EMPTY)
    val LOOP_LINE = SessionCommand(PREFIX + "LOOP_LINE", Bundle.EMPTY)

    /** Switch between the usual speed and the slow one (the lock-screen button). */
    val TOGGLE_SLOW = SessionCommand(PREFIX + "TOGGLE_SLOW", Bundle.EMPTY)

    // Command arguments
    const val ARG_MINUTES = "minutes"
    const val ARG_START_MS = "start_ms"
    const val ARG_END_MS = "end_ms"

    /** [ARG_MINUTES] value meaning "pause at the end of this recording". */
    const val END_OF_RECORDING = 0

    /** [ARG_MINUTES] value meaning "cancel the timer". */
    const val CANCEL = -1

    // Session extras
    private const val EXTRA_SLEEP_ENDS_AT = "sleep_ends_at"
    private const val EXTRA_SLEEP_END_OF_RECORDING = "sleep_end_of_recording"
    private const val EXTRA_LOOP_START = "loop_start_ms"
    private const val EXTRA_LOOP_END = "loop_end_ms"

    const val RESULT_MESSAGE = "message"

    /** The service's state, as published in the session extras. [sleepEndsAt] is in SystemClock.elapsedRealtime. */
    data class ServiceState(
        val sleepEndsAt: Long? = null,
        val sleepAtEndOfRecording: Boolean = false,
        val loopStartMs: Long? = null,
        val loopEndMs: Long? = null,
    ) {
        val sleepActive: Boolean get() = sleepEndsAt != null || sleepAtEndOfRecording

        fun toBundle() = Bundle().apply {
            sleepEndsAt?.let { putLong(EXTRA_SLEEP_ENDS_AT, it) }
            putBoolean(EXTRA_SLEEP_END_OF_RECORDING, sleepAtEndOfRecording)
            loopStartMs?.let { putLong(EXTRA_LOOP_START, it) }
            loopEndMs?.let { putLong(EXTRA_LOOP_END, it) }
        }

        companion object {
            fun from(extras: Bundle) = ServiceState(
                sleepEndsAt = if (extras.containsKey(EXTRA_SLEEP_ENDS_AT)) extras.getLong(EXTRA_SLEEP_ENDS_AT) else null,
                sleepAtEndOfRecording = extras.getBoolean(EXTRA_SLEEP_END_OF_RECORDING),
                loopStartMs = if (extras.containsKey(EXTRA_LOOP_START)) extras.getLong(EXTRA_LOOP_START) else null,
                loopEndMs = if (extras.containsKey(EXTRA_LOOP_END)) extras.getLong(EXTRA_LOOP_END) else null,
            )
        }
    }
}
