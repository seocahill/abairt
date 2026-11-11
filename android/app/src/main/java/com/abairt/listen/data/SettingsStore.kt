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
    /** What says who is asking, from signing in with an emailed link. Empty when signed out. */
    val apiToken: String = "",
    /** The name on the account, to say who is signed in. */
    val accountName: String = "",
    /** Show lines no person has checked yet (the machine's transcript), marked as such. */
    val showUnchecked: Boolean = true,
    val translations: TranslationMode = TranslationMode.TAP,
    /** The usual speed. */
    val speed: Float = 1f,
    /** One tap away (in the app or on the lock screen) for a hard stretch. */
    val slowSpeed: Float = DEFAULT_SLOW_SPEED,
    val slow: Boolean = false,
    /** Whether the transcript was open last, so the app opens where you left it. */
    val studyView: Boolean = false,
    /** Show the line being spoken on the lock screen, to read it without unlocking. */
    val lineOnLockScreen: Boolean = true,
) {
    val connection: Connection get() = Connection(serverUrl.trim(), apiToken)

    val isSignedIn: Boolean get() = apiToken.isNotBlank()

    /** The speed to play at now. */
    val playbackSpeed: Float get() = if (slow) slowSpeed else speed

    /** Picking a speed sets the one in use: the slow speed while slowed down, else the usual one. */
    fun withPlaybackSpeed(chosen: Float): AppSettings = if (slow) copy(slowSpeed = chosen) else copy(speed = chosen)

    companion object {
        const val DEFAULT_SERVER = "https://abairt.com"
        const val DEFAULT_SLOW_SPEED = 0.75f
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

    suspend fun toggleSlow() = update { it.copy(slow = !it.slow) }

    private fun Preferences.toSettings() = AppSettings(
        serverUrl = this[SERVER_URL] ?: AppSettings.DEFAULT_SERVER,
        apiToken = this[API_TOKEN] ?: "",
        accountName = this[ACCOUNT_NAME] ?: "",
        showUnchecked = this[SHOW_UNCHECKED] ?: true,
        translations = this[TRANSLATIONS]?.let { runCatching { TranslationMode.valueOf(it) }.getOrNull() } ?: TranslationMode.TAP,
        speed = this[SPEED] ?: 1f,
        slowSpeed = this[SLOW_SPEED] ?: AppSettings.DEFAULT_SLOW_SPEED,
        slow = this[SLOW] ?: false,
        studyView = this[STUDY_VIEW] ?: false,
        lineOnLockScreen = this[LINE_ON_LOCK_SCREEN] ?: true,
    )

    private fun androidx.datastore.preferences.core.MutablePreferences.write(settings: AppSettings) {
        this[SERVER_URL] = settings.serverUrl
        if (settings.apiToken.isBlank()) remove(API_TOKEN) else this[API_TOKEN] = settings.apiToken
        this[ACCOUNT_NAME] = settings.accountName
        this[SHOW_UNCHECKED] = settings.showUnchecked
        this[TRANSLATIONS] = settings.translations.name
        this[SPEED] = settings.speed
        this[SLOW_SPEED] = settings.slowSpeed
        this[SLOW] = settings.slow
        this[STUDY_VIEW] = settings.studyView
        this[LINE_ON_LOCK_SCREEN] = settings.lineOnLockScreen
    }

    private companion object {
        val SERVER_URL = stringPreferencesKey("server_url")
        val API_TOKEN = stringPreferencesKey("api_token")
        val ACCOUNT_NAME = stringPreferencesKey("account_name")
        val SHOW_UNCHECKED = booleanPreferencesKey("show_unchecked")
        val TRANSLATIONS = stringPreferencesKey("translations")
        val SPEED = floatPreferencesKey("speed")
        val SLOW_SPEED = floatPreferencesKey("slow_speed")
        val SLOW = booleanPreferencesKey("slow")
        val STUDY_VIEW = booleanPreferencesKey("study_view")
        val LINE_ON_LOCK_SCREEN = booleanPreferencesKey("line_on_lock_screen")
    }
}
