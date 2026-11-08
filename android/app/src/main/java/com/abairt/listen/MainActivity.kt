package com.abairt.listen

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.abairt.listen.ui.AbairtRoot
import com.abairt.listen.ui.AbairtTheme
import com.abairt.listen.ui.PlayerViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: PlayerViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AbairtTheme {
                AbairtRoot(viewModel)
            }
        }
    }
}
