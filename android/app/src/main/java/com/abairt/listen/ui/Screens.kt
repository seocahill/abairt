package com.abairt.listen.ui

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle

private enum class Screen { LISTEN, STUDY, SETTINGS }

/**
 * Three places: listening (the radio, with nothing to read), studying (the
 * transcript following the audio), and settings. Back goes to listening.
 * The app opens on whichever of listening and studying you left it on.
 */
@Composable
fun AbairtRoot(viewModel: PlayerViewModel) {
    var screen by rememberSaveable { mutableStateOf(Screen.LISTEN) }
    var restored by rememberSaveable { mutableStateOf(false) }
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val settings by viewModel.settings.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        if (!restored && viewModel.storedSettings().studyView) screen = Screen.STUDY
        restored = true
    }

    val showTranscript = { open: Boolean ->
        screen = if (open) Screen.STUDY else Screen.LISTEN
        viewModel.rememberStudyView(open)
    }

    // With nothing playing there is no transcript to show: start from listening, and the
    // transcript comes back once the radio does.
    val shown = if (screen == Screen.STUDY && !ui.hasMedia) Screen.LISTEN else screen

    BackHandler(enabled = shown != Screen.LISTEN) {
        if (shown == Screen.STUDY) showTranscript(false) else screen = Screen.LISTEN
    }

    // The API needs a token, so until there is one the app asks to sign in (settings stay reachable).
    if (!restored || (!settings.isSignedIn && shown != Screen.SETTINGS)) {
        if (restored) SignInScreen(viewModel = viewModel, onSettings = { screen = Screen.SETTINGS })
        return
    }

    when (shown) {
        Screen.LISTEN -> ListenScreen(
            viewModel = viewModel,
            ui = ui,
            settings = settings,
            onStudy = { showTranscript(true) },
            onSettings = { screen = Screen.SETTINGS },
        )

        Screen.STUDY -> StudyScreen(
            viewModel = viewModel,
            ui = ui,
            settings = settings,
            onBack = { showTranscript(false) },
        )

        Screen.SETTINGS -> SettingsScreen(
            viewModel = viewModel,
            settings = settings,
            onBack = { screen = Screen.LISTEN },
        )
    }
}
