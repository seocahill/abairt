package com.abairt.listen

import android.app.Application
import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import com.abairt.listen.data.AbairtApi
import com.abairt.listen.data.Connection
import com.abairt.listen.data.SettingsStore
import com.abairt.listen.transcript.TranscriptRepository
import java.io.File
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient

/** The few things the UI and the playback service share. */
@androidx.annotation.OptIn(UnstableApi::class)
class AppGraph(context: Context) {
    val settings = SettingsStore(context)

    private val httpClient = OkHttpClient.Builder()
        .callTimeout(30, TimeUnit.SECONDS)
        .build()

    // Abairt stopped accepting the token (revoked, or the account is gone): forget it, so the app asks to sign in again.
    val api = AbairtApi(
        httpClient,
        connection = { settings.current().connection },
        onSignedOut = { settings.update { it.copy(apiToken = "", accountName = "") } },
    )

    val transcripts = TranscriptRepository(api)

    /** An API client for settings not saved yet, to test them. */
    fun apiFor(connection: Connection) = AbairtApi(httpClient, connection = { connection })

    /** Recently played audio, so scanning back and replaying does not download it again. */
    val audioCache: SimpleCache by lazy {
        SimpleCache(
            File(context.cacheDir, "audio"),
            LeastRecentlyUsedCacheEvictor(AUDIO_CACHE_BYTES),
            StandaloneDatabaseProvider(context),
        )
    }

    private companion object {
        const val AUDIO_CACHE_BYTES = 500L * 1024 * 1024
    }
}

class AbairtApplication : Application() {
    val graph by lazy { AppGraph(this) }
}

val Context.graph: AppGraph get() = (applicationContext as AbairtApplication).graph
