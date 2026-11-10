package com.abairt.listen.transcript

import com.abairt.listen.data.AbairtApi

/**
 * Transcripts of the recordings played lately, shared by the screens and the
 * playback service so a transcript is fetched once whichever needs it first.
 */
class TranscriptRepository(private val api: AbairtApi) {
    private val cache = object : LinkedHashMap<Key, Transcript>(MAX_CACHED, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Key, Transcript>) = size > MAX_CACHED
    }

    /** Throws [com.abairt.listen.data.ApiException] when Abairt cannot be asked. */
    suspend fun get(recordingId: Long, includeUnchecked: Boolean, refresh: Boolean = false): Transcript {
        val key = Key(recordingId, includeUnchecked)
        if (!refresh) synchronized(cache) { cache[key] }?.let { return it }

        val transcript = Transcript(api.transcript(recordingId, includeUnchecked).lines)
        synchronized(cache) { cache[key] = transcript }
        return transcript
    }

    private data class Key(val recordingId: Long, val includeUnchecked: Boolean)

    private companion object {
        const val MAX_CACHED = 8
    }
}
