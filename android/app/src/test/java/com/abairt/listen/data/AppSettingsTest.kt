package com.abairt.listen.data

import org.junit.Assert.assertEquals
import org.junit.Test

class AppSettingsTest {
    @Test
    fun `plays at the usual speed until slowed down`() {
        val settings = AppSettings(speed = 1.15f, slowSpeed = 0.75f)

        assertEquals(1.15f, settings.playbackSpeed)
        assertEquals(0.75f, settings.copy(slow = true).playbackSpeed)
    }

    @Test
    fun `picking a speed sets the one in use`() {
        val usual = AppSettings(speed = 1f, slowSpeed = 0.75f).withPlaybackSpeed(1.3f)
        assertEquals(1.3f, usual.speed)
        assertEquals(0.75f, usual.slowSpeed)

        val slowed = AppSettings(speed = 1f, slowSpeed = 0.75f, slow = true).withPlaybackSpeed(0.5f)
        assertEquals(1f, slowed.speed)
        assertEquals(0.5f, slowed.slowSpeed)
    }
}
