package com.abairt.listen.transcript

import com.abairt.listen.data.Line

/**
 * The lines of a recording in the order they are heard, and the questions a
 * listener asks of them: which line is playing, where does the previous one
 * start.
 */
class Transcript(lines: List<Line>) {
    val lines: List<Line> = lines.sortedBy { it.startMs }

    val isEmpty: Boolean get() = lines.isEmpty()

    /**
     * The line playing at [positionMs]: the latest one that has started. In a
     * pause between lines it stays on the line just heard. -1 before the first.
     */
    fun activeIndexAt(positionMs: Long): Int {
        var low = 0
        var high = lines.lastIndex
        var found = -1
        while (low <= high) {
            val mid = (low + high) ushr 1
            if (lines[mid].startMs <= positionMs) {
                found = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return found
    }

    /**
     * Where "back one line" goes: the start of the line playing, or of the one
     * before it when this one has only just begun (so pressing twice scans
     * back). Null when there is nowhere earlier than the start.
     */
    fun backTargetMs(positionMs: Long, restartWithinMs: Long = RESTART_WITHIN_MS): Long? {
        val index = activeIndexAt(positionMs)
        if (index < 0) return null
        val line = lines[index]
        return when {
            positionMs - line.startMs > restartWithinMs -> line.startMs
            index > 0 -> lines[index - 1].startMs
            else -> line.startMs
        }
    }

    /** The start of the line after the one playing, or null at the last line. */
    fun nextTargetMs(positionMs: Long): Long? = lines.getOrNull(activeIndexAt(positionMs) + 1)?.startMs

    companion object {
        /** Pressing back this soon after a line began goes to the line before. */
        const val RESTART_WITHIN_MS = 1_500L
    }
}
