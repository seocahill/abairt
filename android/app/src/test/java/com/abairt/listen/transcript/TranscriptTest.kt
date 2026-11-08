package com.abairt.listen.transcript

import com.abairt.listen.data.Line
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TranscriptTest {
    private fun line(id: Long, start: Double, end: Double) = Line(id = id, irish = "line $id", start = start, end = end)

    // Lines at 1-3s, 5-8s, 9-12s, with a pause between each.
    private val transcript = Transcript(listOf(line(3, 9.0, 12.0), line(1, 1.0, 3.0), line(2, 5.0, 8.0)))

    @Test
    fun `puts lines in the order they are heard`() {
        assertEquals(listOf(1L, 2L, 3L), transcript.lines.map { it.id })
    }

    @Test
    fun `nothing is active before the first line`() {
        assertEquals(-1, transcript.activeIndexAt(0))
        assertEquals(-1, transcript.activeIndexAt(999))
    }

    @Test
    fun `the line playing is the latest one that has started`() {
        assertEquals(0, transcript.activeIndexAt(1_000))
        assertEquals(0, transcript.activeIndexAt(2_999))
        assertEquals(1, transcript.activeIndexAt(5_000))
        assertEquals(2, transcript.activeIndexAt(500_000))
    }

    @Test
    fun `a pause between lines stays on the line just heard`() {
        assertEquals(0, transcript.activeIndexAt(4_000))
    }

    @Test
    fun `back restarts the line playing`() {
        assertEquals(5_000L, transcript.backTargetMs(7_000))
    }

    @Test
    fun `back soon after a line began goes to the one before`() {
        assertEquals(1_000L, transcript.backTargetMs(5_400))
    }

    @Test
    fun `back on the first line restarts it, and before it goes nowhere`() {
        assertEquals(1_000L, transcript.backTargetMs(1_200))
        assertNull(transcript.backTargetMs(500))
    }

    @Test
    fun `next goes to the following line, and nowhere after the last`() {
        assertEquals(5_000L, transcript.nextTargetMs(1_500))
        assertEquals(1_000L, transcript.nextTargetMs(0))
        assertNull(transcript.nextTargetMs(10_000))
    }

    @Test
    fun `an empty transcript has no active line and nowhere to go`() {
        val empty = Transcript(emptyList())

        assertEquals(-1, empty.activeIndexAt(5_000))
        assertNull(empty.nextTargetMs(5_000))
        assertNull(empty.backTargetMs(5_000))
    }
}
