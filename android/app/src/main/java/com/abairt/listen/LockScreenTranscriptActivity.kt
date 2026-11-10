package com.abairt.listen

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.abairt.listen.ui.AbairtTheme
import com.abairt.listen.ui.PlayerViewModel
import com.abairt.listen.ui.StudyScreen

/**
 * The transcript on its own, opened by tapping the media card: on the lock
 * screen it shows without unlocking (declared showWhenLocked in the manifest,
 * which is what the system checks before launching from the lock screen), so
 * the whole line the card had to cut short can be read in the dark. Nothing
 * else in the app is reachable from here; leaving it brings the lock back.
 */
class LockScreenTranscriptActivity : ComponentActivity() {
    private val viewModel: PlayerViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AbairtTheme {
                val ui by viewModel.ui.collectAsStateWithLifecycle()
                val settings by viewModel.settings.collectAsStateWithLifecycle()
                StudyScreen(viewModel = viewModel, ui = ui, settings = settings, onBack = ::finish)
            }
        }
    }
}
