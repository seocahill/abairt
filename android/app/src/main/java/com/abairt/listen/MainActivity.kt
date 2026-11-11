package com.abairt.listen

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.abairt.listen.data.LoginLink
import com.abairt.listen.ui.AbairtRoot
import com.abairt.listen.ui.AbairtTheme
import com.abairt.listen.ui.PlayerViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: PlayerViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // A rotation reopens the activity with the same intent: the link has been used by then.
        if (savedInstanceState == null) signInFrom(intent)
        setContent {
            AbairtTheme {
                AbairtRoot(viewModel)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        signInFrom(intent)
    }

    /** The sign-in link in the email opens the app with its token. */
    private fun signInFrom(intent: Intent) {
        LoginLink.token(intent.dataString)?.let { viewModel.signIn(it) }
    }
}
