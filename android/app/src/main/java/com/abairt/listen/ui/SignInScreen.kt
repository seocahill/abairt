package com.abairt.listen.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.abairt.listen.R

/**
 * Listening needs an Abairt account. Like the website, there is no password:
 * ask for a link by email and open it on this phone.
 */
@Composable
fun SignInScreen(viewModel: PlayerViewModel, onSettings: () -> Unit) {
    val state by viewModel.signInState.collectAsStateWithLifecycle()
    var email by rememberSaveable { mutableStateOf("") }

    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 24.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            Text(stringResource(R.string.sign_in_title), style = MaterialTheme.typography.headlineMedium)

            when (val current = state) {
                is SignInState.LinkSent -> {
                    Text(stringResource(R.string.check_email, current.email))
                    OutlinedButton(onClick = viewModel::restartSignIn) { Text(stringResource(R.string.use_another_email)) }
                }

                SignInState.SigningIn -> {
                    Text(stringResource(R.string.signing_in))
                    CircularProgressIndicator()
                }

                else -> {
                    Text(stringResource(R.string.sign_in_blurb))
                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it },
                        label = { Text(stringResource(R.string.email)) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    if (current is SignInState.Failed) {
                        Text(current.message, color = MaterialTheme.colorScheme.error)
                    }
                    Button(
                        onClick = { viewModel.requestLink(email) },
                        enabled = email.isNotBlank() && current != SignInState.Sending,
                    ) { Text(stringResource(R.string.email_me_a_link)) }
                }
            }

            TextButton(onClick = onSettings) { Text(stringResource(R.string.open_settings)) }
        }
    }
}
