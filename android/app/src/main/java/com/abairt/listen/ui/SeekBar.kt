package com.abairt.listen.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier

/** Scrub through the recording; holds where your finger is until you let go, then seeks once. */
@Composable
fun SeekBar(position: Long, durationMs: Long, onSeek: (Long) -> Unit, modifier: Modifier = Modifier) {
    var dragging by remember { mutableStateOf<Float?>(null) }
    val total = durationMs.coerceAtLeast(1L).toFloat()
    val shown = dragging ?: position.coerceIn(0L, durationMs.coerceAtLeast(0L)).toFloat()

    Column(modifier.fillMaxWidth()) {
        Slider(
            value = shown,
            onValueChange = { dragging = it },
            onValueChangeFinished = {
                dragging?.let { onSeek(it.toLong()) }
                dragging = null
            },
            valueRange = 0f..total,
        )
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(formatTime(shown.toLong()), style = MaterialTheme.typography.labelMedium)
            Text(formatTime(durationMs), style = MaterialTheme.typography.labelMedium)
        }
    }
}
