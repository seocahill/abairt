package com.abairt.listen.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The answer to `POST /api/sessions`: the account's API token, for the app to send from then on. */
@Serializable
data class SignedIn(
    @SerialName("api_token") val apiToken: String,
    val name: String? = null,
)

/** A recording to pick from, as listed by `GET /api/voice_recordings`. */
@Serializable
data class RecordingSummary(
    val id: Long,
    val title: String,
    @SerialName("duration_seconds") val durationSeconds: Double = 0.0,
    @SerialName("dialect_region") val dialectRegion: String? = null,
    @SerialName("lines_count") val linesCount: Int = 0,
    @SerialName("audio_url") val audioUrl: String,
)

@Serializable
data class RecordingList(val recordings: List<RecordingSummary> = emptyList())

@Serializable
data class Speaker(
    val id: Long,
    val name: String? = null,
    val dialect: String? = null,
)

/** One line of a transcript, timed in seconds from the start of the recording. */
@Serializable
data class Line(
    val id: Long,
    val irish: String,
    val translation: String? = null,
    /** Whether a person has checked this line; the rest are the machine's. */
    val checked: Boolean = true,
    val start: Double,
    val end: Double,
    val speaker: Speaker? = null,
) {
    val startMs: Long get() = (start * 1000).toLong()
    val endMs: Long get() = (end * 1000).toLong()
}

/** A recording with its transcript, as returned by `GET /api/voice_recordings/:id`. */
@Serializable
data class RecordingTranscript(
    val id: Long,
    val title: String,
    @SerialName("duration_seconds") val durationSeconds: Double = 0.0,
    @SerialName("dialect_region") val dialectRegion: String? = null,
    @SerialName("audio_url") val audioUrl: String? = null,
    val lines: List<Line> = emptyList(),
)
