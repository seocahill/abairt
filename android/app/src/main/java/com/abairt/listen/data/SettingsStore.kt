package com.abairt.listen.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

enum class TranslationMode {
    /** English stays out of the way until you tap a line. */
    TAP,
    ALWAYS,
}

data class AppSettings(
    val serverUrl: String = DEFAULT_SERVER,
    val token: String = "",
    /** Show lines no person has checked yet (the machine's transcript), marked as such. */
    val showUnchecked: Boolean = true,
    val translations: TranslationMode = TranslationMode.TAP,
    val speed: Float = 1f,
) {
    val connection: Connection get() = Connection(serverUrl.trim(), token.trim())

    companion object {
        const val DEFAULT_SERVER = "https://abairt.com"
    }
}

private val Context.dataStore by preferencesDataStore(name = "settings")

/** What the listener has chosen, kept on the phone. */
class SettingsStore(private val context: Context) {
    val settings: Flow<AppSettings> = context.dataStore.data.map { it.toSettings() }

    suspend fun current(): AppSettings = settings.first()

    suspend fun update(change: (AppSettings) -> AppSettings) {
        context.dataStore.edit { prefs -> prefs.write(change(prefs.toSettings())) }
    }

    private fun Preferences.toSettings() = AppSettings(
        serverUrl = this[SERVER_URL] ?: AppSettings.DEFAULT_SERVER,
        token = this[TOKEN] ?: "",
        showUnchecked = this[SHOW_UNCHECKED] ?: true,
        translations = this[TRANSLATIONS]?.let { runCatching { TranslationMode.valueOf(it) }.getOrNull() } ?: TranslationMode.TAP,
        speed = this[SPEED] ?: 1f,
    )

    private fun androidx.datastore.preferences.core.MutablePreferences.write(settings: AppSettings) {
        this[SERVER_URL] = settings.serverUrl
        this[TOKEN] = settings.token
        this[SHOW_UNCHECKED] = settings.showUnchecked
        this[TRANSLATIONS] = settings.translations.name
        this[SPEED] = settings.speed
    }

    private companion object {
        val SERVER_URL = stringPreferencesKey("server_url")
        val TOKEN = stringPreferencesKey("api_token")
        val SHOW_UNCHECKED = booleanPreferencesKey("show_unchecked")
        val TRANSLATIONS = stringPreferencesKey("translations")
        val SPEED = floatPreferencesKey("speed")
    }
}
