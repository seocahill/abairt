package com.abairt.listen.ui

import android.app.Activity
import android.os.Build
import android.view.WindowManager
import androidx.activity.compose.LocalActivity
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.DragInteraction
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.Replay10
import androidx.compose.material.icons.filled.RepeatOne
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.abairt.listen.R
import com.abairt.listen.data.AppSettings
import com.abairt.listen.data.Line
import com.abairt.listen.data.TranslationMode
import com.abairt.listen.transcript.Transcript

/**
 * Study mode: the transcript follows the audio. Tap a line to hear it, repeat
 * it, slow it down, step back a line at a time, tap the translation icon to
 * check the English.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudyScreen(
    viewModel: PlayerViewModel,
    ui: PlayerUi,
    settings: AppSettings,
    onBack: () -> Unit,
) {
    val position by viewModel.position.collectAsStateWithLifecycle(initialValue = 0L)
    NightReading(playing = ui.isPlaying || ui.isBuffering)

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(ui.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                    }
                },
                actions = { TranscriptToggle(open = true, onToggle = { onBack() }) },
            )
        },
        bottomBar = { StudyControls(viewModel, ui, settings, position) },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (val state = ui.transcript) {
                TranscriptState.None, TranscriptState.Loading ->
                    CircularProgressIndicator(Modifier.align(Alignment.Center))

                is TranscriptState.Failed -> Column(
                    Modifier.align(Alignment.Center).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(stringResource(R.string.transcript_failed), style = MaterialTheme.typography.titleMedium)
                    Text(state.message, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    TextButton(onClick = viewModel::retryTranscript) { Text(stringResource(R.string.retry)) }
                }

                is TranscriptState.Ready ->
                    if (state.transcript.isEmpty) {
                        Text(
                            stringResource(R.string.no_transcript),
                            modifier = Modifier.align(Alignment.Center).padding(24.dp),
                        )
                    } else {
                        TranscriptList(
                            transcript = state.transcript,
                            position = { position },
                            translations = settings.translations,
                            loopStartMs = ui.service.loopStartMs,
                            onPlayLine = viewModel::playLine,
                        )
                    }
            }
        }
    }
}

@Composable
private fun TranscriptList(
    transcript: Transcript,
    // A lambda, so derivedStateOf reads the position's State and tracks it: the
    // list then recomposes when the playing line changes, not on every tick.
    position: () -> Long,
    translations: TranslationMode,
    loopStartMs: Long?,
    onPlayLine: (Line) -> Unit,
) {
    val listState = rememberLazyListState()
    val activeIndex by remember(transcript) { derivedStateOf { transcript.activeIndexAt(position()) } }
    var following by rememberSaveable { mutableStateOf(true) }
    var revealed by rememberSaveable { mutableStateOf(setOf<Long>()) }

    // Keep the playing line in view, until you scroll yourself; "Now" brings the following back.
    LaunchedEffect(activeIndex, following) {
        if (following && activeIndex >= 0) listState.animateScrollToItem((activeIndex - 1).coerceAtLeast(0))
    }
    LaunchedEffect(listState) {
        listState.interactionSource.interactions.collect { if (it is DragInteraction.Start) following = false }
    }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(state = listState, contentPadding = PaddingValues(bottom = 96.dp), modifier = Modifier.fillMaxSize()) {
            itemsIndexed(transcript.lines, key = { _, line -> line.id }) { index, line ->
                LineRow(
                    line = line,
                    active = index == activeIndex,
                    looping = loopStartMs == line.startMs,
                    showTranslation = translations == TranslationMode.ALWAYS || line.id in revealed,
                    onPlay = { onPlayLine(line) },
                    onToggleTranslation = {
                        revealed = if (line.id in revealed) revealed - line.id else revealed + line.id
                    },
                )
            }
        }
        if (!following && activeIndex >= 0) {
            ExtendedFloatingActionButton(
                onClick = { following = true },
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 16.dp),
            ) { Text(stringResource(R.string.jump_to_now)) }
        }
    }
}

@Composable
private fun LineRow(
    line: Line,
    active: Boolean,
    looping: Boolean,
    showTranslation: Boolean,
    onPlay: () -> Unit,
    onToggleTranslation: () -> Unit,
) {
    val container = if (active) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.background
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(container)
            .clickable(onClick = onPlay)
            .padding(start = 16.dp, top = 12.dp, bottom = 12.dp, end = 4.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    formatTime(line.startMs),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                line.speaker?.name?.takeIf { it.isNotBlank() }?.let {
                    Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }
                if (looping) {
                    Icon(Icons.Filled.RepeatOne, null, Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                }
            }
            // A machine's guess is shown, but marked, so it is not mistaken for a checked line.
            Text(
                line.irish,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.alpha(if (line.checked) 1f else 0.85f),
            )
            if (!line.checked) {
                Text(
                    stringResource(R.string.unchecked),
                    style = MaterialTheme.typography.labelSmall.copy(fontStyle = FontStyle.Italic),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (showTranslation) {
                Text(
                    line.translation?.takeIf { it.isNotBlank() } ?: stringResource(R.string.no_translation),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
        IconButton(onClick = onToggleTranslation) {
            Icon(
                Icons.Filled.Translate,
                contentDescription = stringResource(if (showTranslation) R.string.hide_translation else R.string.show_translation),
                tint = if (showTranslation) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** Line-sized controls: step back a line, repeat it, slow it down. */
@Composable
private fun StudyControls(viewModel: PlayerViewModel, ui: PlayerUi, settings: AppSettings, position: Long) {
    val transcript = (ui.transcript as? TranscriptState.Ready)?.transcript
    val activeLine = transcript?.lines?.getOrNull(transcript.activeIndexAt(position))
    val looping = activeLine != null && ui.service.loopStartMs == activeLine.startMs

    Surface(color = MaterialTheme.colorScheme.surfaceContainer, tonalElevation = 3.dp) {
        Column(Modifier.fillMaxWidth()) {
            LinearProgressIndicator(
                progress = { if (ui.durationMs > 0) (position.toFloat() / ui.durationMs).coerceIn(0f, 1f) else 0f },
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = viewModel::lineBack) {
                    Icon(Icons.Filled.Replay, stringResource(R.string.back_one_line))
                }
                IconButton(onClick = viewModel::back10) {
                    Icon(Icons.Filled.Replay10, stringResource(R.string.back_10))
                }
                PlayPauseButton(ui.isPlaying, ui.isBuffering, onClick = viewModel::playPause, size = 64.dp)
                IconButton(onClick = viewModel::lineNext) {
                    Icon(Icons.Filled.SkipNext, stringResource(R.string.next_line))
                }
                IconButton(
                    onClick = { activeLine?.let(viewModel::toggleLoop) },
                    enabled = activeLine != null,
                    colors = if (looping) IconButtonDefaults.filledIconButtonColors() else IconButtonDefaults.iconButtonColors(),
                ) {
                    Icon(Icons.Filled.RepeatOne, stringResource(R.string.loop_line))
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
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
    }
}

/**
 * Reading in bed: while the transcript is open and the audio is playing, the
 * screen stays on (so it stops when the sleep timer pauses), and the transcript
 * shows over the lock screen without unlocking. Leaving it (back, or the
 * transcript button) brings the lock back; nothing else is reachable from here.
 */
@Composable
private fun NightReading(playing: Boolean) {
    val view = LocalView.current
    val activity = LocalActivity.current

    DisposableEffect(view, playing) {
        view.keepScreenOn = playing
        onDispose { view.keepScreenOn = false }
    }
    DisposableEffect(activity) {
        activity?.showOverLockScreen(true)
        onDispose { activity?.showOverLockScreen(false) }
    }
}

private fun Activity.showOverLockScreen(show: Boolean) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
        setShowWhenLocked(show)
    } else {
        @Suppress("DEPRECATION")
        if (show) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }
    }
}
