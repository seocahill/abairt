package com.abairt.listen.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LoginLinkTest {
    @Test
    fun `reads the token from the emailed link`() {
        assertEquals("abc-123_def--sig", LoginLink.token("https://abairt.com/app_login/abc-123_def--sig"))
    }

    @Test
    fun `ignores any other address`() {
        assertNull(LoginLink.token(null))
        assertNull(LoginLink.token("not a url"))
        assertNull(LoginLink.token("https://abairt.com/"))
        assertNull(LoginLink.token("https://abairt.com/app_login/"))
        assertNull(LoginLink.token("https://abairt.com/login_with_token/abc"))
    }
}
