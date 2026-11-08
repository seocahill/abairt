package com.abairt.listen.ui

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle

private enum class Screen { LISTEN, STUDY, SETTINGS }

/**
 * Three places: listening (the radio, with nothing to read), studying (the
 * transcript following the audio), and settings. Back goes to listening.
 */
@Composable
fun AbairtRoot(viewModel: PlayerViewModel) {
    var screen by rememberSaveable { mutableStateOf(Screen.LISTEN) }
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val settings by viewModel.settings.collectAsStateWithLifecycle()

    BackHandler(enabled = screen != Screen.LISTEN) { screen = Screen.LISTEN }

    when (screen) {
        Screen.LISTEN -> ListenScreen(
            viewModel = viewModel,
            ui = ui,
            settings = settings,
            onStudy = { screen = Screen.STUDY },
            onSettings = { screen = Screen.SETTINGS },
        )

        Screen.STUDY -> StudyScreen(
            viewModel = viewModel,
            ui = ui,
            settings = settings,
            onBack = { screen = Screen.LISTEN },
        )

        Screen.SETTINGS -> SettingsScreen(
            viewModel = viewModel,
            settings = settings,
            onBack = { screen = Screen.LISTEN },
        )
    }
}
