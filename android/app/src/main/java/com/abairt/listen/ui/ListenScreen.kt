package com.abairt.listen.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Forward10
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Replay10
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.abairt.listen.R
import com.abairt.listen.data.AppSettings

/**
 * Listening mode: nothing to read. A title, big controls, a sleep timer. The
 * transcript is one tap away for when you want to check something.
 */
@Composable
fun ListenScreen(
    viewModel: PlayerViewModel,
    ui: PlayerUi,
    settings: AppSettings,
    onStudy: () -> Unit,
    onSettings: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(ui.message) {
        ui.message?.let {
            snackbar.showSnackbar(it)
            viewModel.messageShown()
        }
    }

    // From Android 13 the playback notification (and its lock-screen controls) needs this permission.
    val askNotifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        viewModel.startRadio()
    }
    val start = {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            viewModel.startRadio()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        containerColor = MaterialTheme.colorScheme.background,
        modifier = Modifier.safeDrawingPadding(),
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                IconButton(onClick = onSettings) {
                    Icon(Icons.Filled.Settings, contentDescription = stringResource(R.string.open_settings))
                }
                if (ui.hasMedia) TranscriptToggle(open = false, onToggle = { onStudy() })
            }
            Spacer(Modifier.weight(1f))
            if (ui.hasMedia) {
                NowPlaying(viewModel, ui, settings)
            } else {
                StartPanel(configured = settings.connection.isConfigured, onStart = start, onSettings = onSettings)
            }
            Spacer(Modifier.weight(1f))
            if (ui.hasMedia) {
                FilledTonalButton(onClick = onStudy, modifier = Modifier.padding(bottom = 16.dp)) {
                    Text(stringResource(R.string.transcript))
                }
            }
        }
    }
}

@Composable
private fun StartPanel(configured: Boolean, onStart: () -> Unit, onSettings: () -> Unit) {
    Icon(
        Icons.Filled.GraphicEq,
        contentDescription = null,
        modifier = Modifier.size(72.dp),
        tint = MaterialTheme.colorScheme.primary,
    )
    Spacer(Modifier.height(16.dp))
    Text(
        stringResource(R.string.start_blurb),
        style = MaterialTheme.typography.titleMedium,
        textAlign = TextAlign.Center,
    )
    Spacer(Modifier.height(32.dp))
    if (configured) {
        Button(onClick = onStart) { Text(stringResource(R.string.start_radio)) }
    } else {
        Text(
            stringResource(R.string.setup_needed),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(12.dp))
        Button(onClick = onSettings) { Text(stringResource(R.string.open_settings)) }
    }
}

@Composable
private fun NowPlaying(viewModel: PlayerViewModel, ui: PlayerUi, settings: AppSettings) {
    val position by viewModel.position.collectAsStateWithLifecycle(initialValue = 0L)
    val transcript = (ui.transcript as? TranscriptState.Ready)?.transcript
    val speaker = transcript?.lines?.getOrNull(transcript.activeIndexAt(position))?.speaker

    Text(
        ui.title,
        style = MaterialTheme.typography.headlineSmall,
        textAlign = TextAlign.Center,
        maxLines = 3,
    )
    ui.region?.let {
        Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    // Credit the voice you are hearing.
    speaker?.name?.takeIf { it.isNotBlank() }?.let {
        Spacer(Modifier.height(4.dp))
        Text(
            stringResource(R.string.speaker_credit, it),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.primary,
        )
    }
    Spacer(Modifier.height(24.dp))
    SeekBar(position = position, durationMs = ui.durationMs, onSeek = { viewModel.seekTo(it) })
    Spacer(Modifier.height(16.dp))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = viewModel::previousRecording, modifier = Modifier.size(56.dp)) {
            Icon(Icons.Filled.SkipPrevious, stringResource(R.string.previous_recording), Modifier.size(32.dp))
        }
        IconButton(onClick = viewModel::back10, modifier = Modifier.size(56.dp)) {
            Icon(Icons.Filled.Replay10, stringResource(R.string.back_10), Modifier.size(36.dp))
        }
        PlayPauseButton(ui.isPlaying, ui.isBuffering, onClick = viewModel::playPause)
        IconButton(onClick = viewModel::forward10, modifier = Modifier.size(56.dp)) {
            Icon(Icons.Filled.Forward10, stringResource(R.string.forward_10), Modifier.size(36.dp))
        }
        IconButton(onClick = viewModel::nextRecording, modifier = Modifier.size(56.dp)) {
            Icon(Icons.Filled.SkipNext, stringResource(R.string.next_recording), Modifier.size(32.dp))
        }
    }
    Spacer(Modifier.height(24.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SlowChip(settings.slow, onToggle = viewModel::toggleSlow)
        SpeedChip(ui.speed, onSelect = viewModel::setSpeed)
        SleepChip(
            state = ui.service,
            onMinutes = viewModel::sleepIn,
            onEndOfRecording = viewModel::sleepAtEndOfRecording,
            onCancel = viewModel::cancelSleep,
        )
    }
}
