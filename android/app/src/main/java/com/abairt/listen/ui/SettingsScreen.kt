package com.abairt.listen.ui

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.abairt.listen.R
import com.abairt.listen.data.AppSettings
import com.abairt.listen.data.TranslationMode
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(viewModel: PlayerViewModel, settings: AppSettings, onBack: () -> Unit) {
    var server by remember(settings.serverUrl) { mutableStateOf(settings.serverUrl) }
    var token by remember(settings.token) { mutableStateOf(settings.token) }
    var status by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val connected = stringResource(R.string.connection_ok)
    val saved = stringResource(R.string.saved)

    LaunchedEffect(server, token) { status = null }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier.padding(padding).padding(horizontal = 16.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            OutlinedTextField(
                value = server,
                onValueChange = { server = it },
                label = { Text(stringResource(R.string.server)) },
                singleLine = true,
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Uri),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = token,
                onValueChange = { token = it },
                label = { Text(stringResource(R.string.api_token)) },
                supportingText = { Text(stringResource(R.string.api_token_help)) },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = {
                    viewModel.saveSettings { it.copy(serverUrl = server.trim(), token = token.trim()) }
                    status = saved
                }) { Text(stringResource(R.string.save)) }
                OutlinedButton(onClick = {
                    scope.launch {
                        val candidate = settings.copy(serverUrl = server, token = token)
                        status = viewModel.checkConnection(candidate) ?: connected
                    }
                }) { Text(stringResource(R.string.test_connection)) }
                status?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
            }

            SettingSwitch(
                title = R.string.line_on_lock_screen,
                help = R.string.line_on_lock_screen_help,
                checked = settings.lineOnLockScreen,
                onChange = { checked -> viewModel.saveSettings { it.copy(lineOnLockScreen = checked) } },
            )

            SettingSwitch(
                title = R.string.show_unchecked,
                help = R.string.show_unchecked_help,
                checked = settings.showUnchecked,
                onChange = { checked -> viewModel.saveSettings { it.copy(showUnchecked = checked) } },
            )

            Text(stringResource(R.string.translations), style = MaterialTheme.typography.titleSmall)
            TranslationOption(R.string.translations_tap, TranslationMode.TAP, settings.translations, viewModel)
            TranslationOption(R.string.translations_always, TranslationMode.ALWAYS, settings.translations, viewModel)
        }
    }
}

@Composable
private fun SettingSwitch(@StringRes title: Int, @StringRes help: Int, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(stringResource(title), style = MaterialTheme.typography.titleSmall)
            Text(
                stringResource(help),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun TranslationOption(label: Int, mode: TranslationMode, current: TranslationMode, viewModel: PlayerViewModel) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .selectable(selected = mode == current, role = Role.RadioButton) {
                viewModel.saveSettings { it.copy(translations = mode) }
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = mode == current, onClick = null)
        Text(stringResource(label), modifier = Modifier.padding(start = 12.dp))
    }
}
