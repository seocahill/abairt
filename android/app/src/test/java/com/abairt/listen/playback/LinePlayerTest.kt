package com.abairt.listen.playback

import androidx.media3.common.MediaMetadata
import com.abairt.listen.data.Line
import org.junit.Assert.assertEquals
import org.junit.Test

class LinePlayerTest {
    private val recording = MediaMetadata.Builder().setTitle("A recording").setArtist("erris").build()

    private fun line(translation: String?) = Line(id = 1, irish = "an líne", translation = translation, start = 0.0, end = 1.0)

    @Test
    fun `the lock screen shows the line with its English beneath`() {
        val shown = recording.showingLine(line("the line"))

        assertEquals("an líne", shown.title)
        assertEquals("the line", shown.artist)
    }

    @Test
    fun `without English it keeps the recording's title beneath`() {
        assertEquals("A recording", recording.showingLine(line(null)).artist)
        assertEquals("A recording", recording.showingLine(line(" ")).artist)
    }
}
