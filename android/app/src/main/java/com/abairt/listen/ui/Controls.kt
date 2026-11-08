package com.abairt.listen.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.abairt.listen.R
import com.abairt.listen.playback.PlaybackProtocol.ServiceState
import kotlinx.coroutines.delay
import android.os.SystemClock

/** Play or pause, big enough to find in the dark. */
@Composable
fun PlayPauseButton(
    isPlaying: Boolean,
    isBuffering: Boolean,
    onClick: () -> Unit,
    size: Dp = 88.dp,
) {
    FilledIconButton(
        onClick = onClick,
        modifier = Modifier.size(size),
        colors = IconButtonDefaults.filledIconButtonColors(),
    ) {
        Box(contentAlignment = Alignment.Center) {
            if (isBuffering) CircularProgressIndicator(modifier = Modifier.size(size * 0.7f), strokeWidth = 3.dp)
            Icon(
                imageVector = if (isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                contentDescription = stringResource(if (isPlaying) R.string.pause else R.string.play),
                modifier = Modifier.size(size * 0.5f),
            )
        }
    }
}

@Composable
fun SpeedChip(speed: Float, onSelect: (Float) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        AssistChip(
            onClick = { open = true },
            label = { Text(stringResource(R.string.speed_label, formatSpeed(speed))) },
            leadingIcon = { Icon(Icons.Filled.Speed, contentDescription = null, modifier = Modifier.size(18.dp)) },
        )
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            PLAYBACK_SPEEDS.forEach { option ->
                DropdownMenuItem(
                    text = { Text(formatSpeed(option)) },
                    onClick = {
                        onSelect(option)
                        open = false
                    },
                )
            }
        }
    }
}

/** The sleep timer: pick minutes or "end of recording"; shows what is left once set. */
@Composable
fun SleepChip(
    state: ServiceState,
    onMinutes: (Int) -> Unit,
    onEndOfRecording: () -> Unit,
    onCancel: () -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    val remaining by produceState("", state.sleepEndsAt) {
        val endsAt = state.sleepEndsAt
        if (endsAt == null) {
            value = ""
        } else {
            while (true) {
                value = formatTime(endsAt - SystemClock.elapsedRealtime())
                delay(1_000)
            }
        }
    }
    val label = when {
        state.sleepEndsAt != null -> stringResource(R.string.sleep_remaining, remaining)
        state.sleepAtEndOfRecording -> stringResource(R.string.sleep_at_end)
        else -> stringResource(R.string.sleep_timer)
    }
    Box {
        AssistChip(
            onClick = { open = true },
            label = { Text(label) },
            leadingIcon = { Icon(Icons.Filled.Bedtime, contentDescription = null, modifier = Modifier.size(18.dp)) },
        )
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            SLEEP_MINUTES.forEach { minutes ->
                DropdownMenuItem(
                    text = { Text(pluralStringResource(R.plurals.sleep_minutes, minutes, minutes)) },
                    onClick = {
                        onMinutes(minutes)
                        open = false
                    },
                )
            }
            DropdownMenuItem(
                text = { Text(stringResource(R.string.sleep_end_of_recording)) },
                onClick = {
                    onEndOfRecording()
                    open = false
                },
            )
            if (state.sleepActive) {
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.sleep_off)) },
                    onClick = {
                        onCancel()
                        open = false
                    },
                )
            }
        }
    }
}

private val SLEEP_MINUTES = listOf(15, 30, 45, 60, 90)
