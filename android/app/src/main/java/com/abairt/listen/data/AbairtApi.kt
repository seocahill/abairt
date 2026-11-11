package com.abairt.listen.data

import android.util.Log
import java.io.IOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

/** Where the app talks to. Listening is open to anyone, like the website, so there is no sign-in. */
data class Connection(val baseUrl: String) {
    val isConfigured: Boolean get() = baseUrl.toHttpUrlOrNull() != null
}

/** Why a request to Abairt did not give us what we wanted. */
sealed class ApiException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class NotConfigured : ApiException("Set the server in settings.")
    class RateLimited : ApiException("Abairt says too many requests. Try again later.")
    class NotFound : ApiException("Abairt has no such recording.")
    class Server(val code: Int) : ApiException("Abairt answered with an error ($code).")
    class Network(cause: Throwable) : ApiException("Could not reach Abairt.", cause)
    class Unreadable(cause: Throwable) : ApiException("Abairt sent something this app could not read.", cause)
}

/**
 * The slice of the Abairt API this app uses: recordings to play, and the
 * transcript of one.
 */
class AbairtApi(
    private val client: OkHttpClient,
    private val connection: suspend () -> Connection,
    private val json: Json = Json { ignoreUnknownKeys = true },
    private val io: CoroutineDispatcher = Dispatchers.IO,
) {
    /** A batch of random recordings, leaving out ones already heard. */
    suspend fun radioBatch(limit: Int, excludeIds: Collection<Long> = emptyList()): List<RecordingSummary> {
        val request = request("api", "voice_recordings") {
            addQueryParameter("shuffle", "true")
            addQueryParameter("limit", limit.toString())
            excludeIds.forEach { addQueryParameter("exclude_ids[]", it.toString()) }
        }
        return get(request) { json.decodeFromString<RecordingList>(it).recordings }
    }

    suspend fun transcript(id: Long, includeUnchecked: Boolean): RecordingTranscript {
        val request = request("api", "voice_recordings", id.toString()) {
            if (includeUnchecked) addQueryParameter("unchecked", "true")
        }
        return get(request) { json.decodeFromString<RecordingTranscript>(it) }
    }

    private suspend fun request(vararg segments: String, query: HttpUrl.Builder.() -> Unit): Request {
        val conn = connection()
        if (!conn.isConfigured) throw ApiException.NotConfigured()
        val url = conn.baseUrl.toHttpUrlOrNull()!!.newBuilder().apply {
            segments.forEach { addPathSegment(it) }
            query()
        }.build()
        return Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .build()
    }

    // The body is read from the socket while parsing, so the whole exchange
    // stays off the main thread (await() resumes on the caller's dispatcher).
    private suspend fun <T> get(request: Request, parse: (String) -> T): T = withContext(io) {
        val response = try {
            client.newCall(request).await()
        } catch (e: IOException) {
            Log.w(TAG, "Request to ${request.url.host} failed", e)
            throw ApiException.Network(e)
        }
        response.use {
            when (it.code) {
                in 200..299 -> try {
                    parse(it.body.string())
                } catch (e: SerializationException) {
                    throw ApiException.Unreadable(e)
                }
                404 -> throw ApiException.NotFound()
                429 -> throw ApiException.RateLimited()
                else -> throw ApiException.Server(it.code)
            }
        }
    }
}

private suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) = continuation.resume(response)
        override fun onFailure(call: Call, e: IOException) = continuation.resumeWithException(e)
    })
    continuation.invokeOnCancellation { cancel() }
}

private const val TAG = "AbairtApi"
