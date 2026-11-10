package com.abairt.listen.data

import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test

class AbairtApiTest {
    private val server = MockWebServer()
    private lateinit var api: AbairtApi

    @Before
    fun setUp() {
        server.start()
        api = AbairtApi(OkHttpClient(), connection = { Connection(server.url("/").toString()) })
    }

    @After
    fun tearDown() = server.shutdown()

    @Test
    fun `asks for a shuffled batch, leaving out what was heard, without signing in`() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"recordings":[]}"""))

        api.radioBatch(limit = 5, excludeIds = listOf(7, 9))

        val request = server.takeRequest()
        assertNull(request.getHeader("Authorization"))
        assertEquals("/api/voice_recordings", request.requestUrl!!.encodedPath)
        assertEquals("true", request.requestUrl!!.queryParameter("shuffle"))
        assertEquals("5", request.requestUrl!!.queryParameter("limit"))
        assertEquals(listOf("7", "9"), request.requestUrl!!.queryParameterValues("exclude_ids[]"))
    }

    @Test
    fun `reads recordings and ignores fields it does not know`() = runBlocking {
        server.enqueue(
            MockResponse().setBody(
                """{"recordings":[{"id":12,"title":"A title","duration_seconds":95.5,"dialect_region":"Iorras","lines_count":30,
                   "audio_url":"https://abairt.test/audio.mp3","something_new":true}]}""",
            ),
        )

        val recording = api.radioBatch(limit = 1).single()

        assertEquals(12L, recording.id)
        assertEquals("Iorras", recording.dialectRegion)
        assertEquals("https://abairt.test/audio.mp3", recording.audioUrl)
    }

    @Test
    fun `reads a transcript with lines, whether checked, and a missing speaker`() = runBlocking {
        server.enqueue(
            MockResponse().setBody(
                """{"id":3,"title":"T","duration_seconds":10.0,"dialect_region":null,"audio_url":"https://x/a.mp3","lines":[
                  {"id":1,"irish":"a","translation":"A","checked":true,"start":1.5,"end":3.0,"speaker":{"id":2,"name":"Sinéad","dialect":"Iorras"}},
                  {"id":2,"irish":"b","translation":null,"checked":false,"start":4.0,"end":5.0,"speaker":null}]}""",
            ),
        )

        val transcript = api.transcript(3, includeUnchecked = true)

        assertEquals("true", server.takeRequest().requestUrl!!.queryParameter("unchecked"))
        assertEquals(1_500L, transcript.lines[0].startMs)
        assertEquals("Sinéad", transcript.lines[0].speaker?.name)
        assertFalse(transcript.lines[1].checked)
        assertNull(transcript.lines[1].speaker)
    }

    @Test
    fun `only asks for unchecked lines when told to`() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"id":3,"title":"T"}"""))

        api.transcript(3, includeUnchecked = false)

        assertNull(server.takeRequest().requestUrl!!.queryParameter("unchecked"))
    }

    @Test
    fun `tells rate limiting, missing recordings and server errors apart`() {
        server.enqueue(MockResponse().setResponseCode(429))
        server.enqueue(MockResponse().setResponseCode(404))
        server.enqueue(MockResponse().setResponseCode(500))

        assertThrows(ApiException.RateLimited::class.java) { runBlocking { api.transcript(1, false) } }
        assertThrows(ApiException.NotFound::class.java) { runBlocking { api.transcript(1, false) } }
        val error = assertThrows(ApiException.Server::class.java) { runBlocking { api.transcript(1, false) } }
        assertEquals(500, error.code)
    }

    @Test
    fun `a response it cannot read is an API error, not a crash`() {
        server.enqueue(MockResponse().setBody("""{"id":1,"title":"t","lines":[{"id":2,"irish":null,"start":0,"end":1}]}"""))

        assertThrows(ApiException.Unreadable::class.java) { runBlocking { api.transcript(1, true) } }
    }

    @Test
    fun `does not call out until it knows where`() {
        val unconfigured = AbairtApi(OkHttpClient(), connection = { Connection("") })

        assertThrows(ApiException.NotConfigured::class.java) { runBlocking { unconfigured.radioBatch(5) } }
        assertEquals(0, server.requestCount)
        assertFalse(Connection("not a url").isConfigured)
    }
}
