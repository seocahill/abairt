package com.abairt.listen.playback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RadioQueueTest {
    private val radio = RadioQueue(prefetchAhead = 2, keepHistory = 3, excludeLimit = 4)

    @Test
    fun `loads when an empty queue has nothing to play`() {
        assertTrue(radio.shouldLoadMore(currentIndex = 0, count = 0))
    }

    @Test
    fun `loads when fewer than two are waiting after the current one`() {
        assertFalse(radio.shouldLoadMore(currentIndex = 0, count = 4))
        assertTrue(radio.shouldLoadMore(currentIndex = 2, count = 4))
        assertTrue(radio.shouldLoadMore(currentIndex = 3, count = 4))
    }

    @Test
    fun `remembers what was queued, up to a limit, newest last`() {
        radio.queued(listOf(1, 2, 3))
        radio.queued(listOf(4, 5, 6))

        assertEquals(listOf(3L, 4L, 5L, 6L), radio.excludeIds())
    }

    @Test
    fun `starting again forgets`() {
        radio.queued(listOf(1, 2))
        radio.reset()

        assertEquals(emptyList<Long>(), radio.excludeIds())
    }

    @Test
    fun `keeps a few played recordings and trims the rest`() {
        assertEquals(0, radio.itemsToTrim(currentIndex = 2))
        assertEquals(0, radio.itemsToTrim(currentIndex = 3))
        assertEquals(2, radio.itemsToTrim(currentIndex = 5))
    }
}
