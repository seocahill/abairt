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
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response

/** Where the app talks to, and the token that says who is asking (empty until signed in). */
data class Connection(val baseUrl: String, val token: String = "") {
    val isConfigured: Boolean get() = baseUrl.toHttpUrlOrNull() != null
    val isSignedIn: Boolean get() = token.isNotBlank()
}

/** Why a request to Abairt did not give us what we wanted. */
sealed class ApiException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class NotConfigured : ApiException("Set the server in settings.")
    class SignedOut : ApiException("Sign in to listen.")
    class LinkExpired : ApiException("That link has run out or was already used. Ask for a new one.")
    class RateLimited : ApiException("Abairt says too many requests. Try again later.")
    class NotFound : ApiException("Abairt has no such recording.")
    class Server(val code: Int) : ApiException("Abairt answered with an error ($code).")
    class Network(cause: Throwable) : ApiException("Could not reach Abairt.", cause)
    class Unreadable(cause: Throwable) : ApiException("Abairt sent something this app could not read.", cause)
}

/**
 * The slice of the Abairt API this app uses: signing in, recordings to play,
 * and the transcript of one. The API needs a token, so everything but signing
 * in fails with [ApiException.SignedOut] until there is one, and [onSignedOut]
 * is told when Abairt stops accepting the one the app has.
 */
class AbairtApi(
    private val client: OkHttpClient,
    private val connection: suspend () -> Connection,
    private val json: Json = Json { ignoreUnknownKeys = true },
    private val io: CoroutineDispatcher = Dispatchers.IO,
    private val onSignedOut: suspend () -> Unit = {},
) {
    /** Emails a sign-in link to the address. Abairt answers the same whether or not it has an account. */
    suspend fun requestLoginLink(email: String) {
        execute(signInRequest("login_requests", buildJsonObject { put("email", email) })) { }
    }

    /** Swaps the token from the emailed link for the account's API token. The link works once. */
    suspend fun signIn(linkToken: String): SignedIn {
        val request = signInRequest("sessions", buildJsonObject { put("token", linkToken) })
        return execute(request, unauthorized = { ApiException.LinkExpired() }) { json.decodeFromString<SignedIn>(it) }
    }

    /** A batch of random recordings, leaving out ones already heard. */
    suspend fun radioBatch(limit: Int, excludeIds: Collection<Long> = emptyList()): List<RecordingSummary> {
        val request = request("api", "voice_recordings") {
            addQueryParameter("shuffle", "true")
            addQueryParameter("limit", limit.toString())
            excludeIds.forEach { addQueryParameter("exclude_ids[]", it.toString()) }
        }
        return execute(request) { json.decodeFromString<RecordingList>(it).recordings }
    }

    suspend fun transcript(id: Long, includeUnchecked: Boolean): RecordingTranscript {
        val request = request("api", "voice_recordings", id.toString()) {
            if (includeUnchecked) addQueryParameter("unchecked", "true")
        }
        return execute(request) { json.decodeFromString<RecordingTranscript>(it) }
    }

    private suspend fun request(vararg segments: String, query: HttpUrl.Builder.() -> Unit): Request {
        val conn = connection()
        if (!conn.isConfigured) throw ApiException.NotConfigured()
        if (!conn.isSignedIn) throw ApiException.SignedOut()
        val url = conn.baseUrl.toHttpUrlOrNull()!!.newBuilder().apply {
            segments.forEach { addPathSegment(it) }
            query()
        }.build()
        return Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .header("Authorization", "Bearer ${conn.token}")
            .build()
    }

    /** Signing in is the one thing that needs no token. */
    private suspend fun signInRequest(path: String, body: JsonObject): Request {
        val conn = connection()
        if (!conn.isConfigured) throw ApiException.NotConfigured()
        val url = conn.baseUrl.toHttpUrlOrNull()!!.newBuilder().addPathSegment("api").addPathSegment(path).build()
        return Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()
    }

    // The body is read from the socket while parsing, so the whole exchange
    // stays off the main thread (await() resumes on the caller's dispatcher).
    private suspend fun <T> execute(
        request: Request,
        unauthorized: suspend () -> ApiException = {
            onSignedOut()
            ApiException.SignedOut()
        },
        parse: (String) -> T,
    ): T = withContext(io) {
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
                401 -> throw unauthorized()
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
