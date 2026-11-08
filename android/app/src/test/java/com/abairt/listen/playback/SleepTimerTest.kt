package com.abairt.listen.playback

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SleepTimerTest {
    private class FakeControl : SleepTimerControl {
        val volumes = mutableListOf<Float>()
        var paused = 0
        var pauseAtEnd = false

        override fun setVolume(volume: Float) { volumes += volume }
        override fun pause() { paused++ }
        override fun setPauseAtEndOfRecording(enabled: Boolean) { pauseAtEnd = enabled }
    }

    private fun TestScope.timer(control: FakeControl) =
        SleepTimer(backgroundScope, clock = { currentTime }, control = control, onChange = {})

    @Test
    fun `pauses when the minutes are up and leaves the volume restored`() = runTest {
        val control = FakeControl()
        val timer = timer(control)

        timer.startMinutes(15)
        advanceTimeBy(14 * 60_000L)
        assertEquals(0, control.paused)
        assertTrue(timer.state.isActive)

        advanceTimeBy(60_001L)
        assertEquals(1, control.paused)
        assertEquals(1f, control.volumes.last(), 0f)
        assertFalse(timer.state.isActive)
    }

    @Test
    fun `eases the volume down over the last half minute`() = runTest {
        val control = FakeControl()
        val timer = timer(control)

        timer.startMinutes(1)
        advanceTimeBy(45_000L)
        val midFade = control.volumes.last()

        assertTrue("volume $midFade should be below full", midFade < 1f)
        assertTrue("volume $midFade should not be silent yet", midFade > 0f)
        timer.cancel()
    }

    @Test
    fun `cancelling restores the volume and stops the countdown`() = runTest {
        val control = FakeControl()
        val timer = timer(control)

        timer.startMinutes(1)
        advanceTimeBy(50_000L)
        timer.cancel()
        advanceTimeBy(120_000L)

        assertEquals(0, control.paused)
        assertEquals(1f, control.volumes.last(), 0f)
        assertNull(timer.state.endsAtMs)
    }

    @Test
    fun `end of recording asks the player to pause there, and is spent once it has`() = runTest {
        val control = FakeControl()
        val timer = timer(control)

        timer.startEndOfRecording()
        assertTrue(control.pauseAtEnd)
        assertTrue(timer.state.endOfRecording)

        timer.endOfRecordingReached()
        assertFalse(control.pauseAtEnd)
        assertFalse(timer.state.isActive)
    }

    @Test
    fun `starting one replaces another`() = runTest {
        val control = FakeControl()
        val timer = timer(control)

        timer.startMinutes(30)
        timer.startEndOfRecording()
        advanceTimeBy(31 * 60_000L)

        assertEquals(0, control.paused)
        assertTrue(timer.state.endOfRecording)
    }
}
