package com.abairt.listen.data

import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/** The sign-in link emailed by Abairt: `https://abairt.com/app_login/<token>`. */
object LoginLink {
    private const val PATH = "app_login"

    /** The token in the link, or null for any other address. */
    fun token(url: String?): String? {
        val segments = url?.toHttpUrlOrNull()?.pathSegments ?: return null
        return segments.getOrNull(1)?.takeIf { segments[0] == PATH && it.isNotBlank() }
    }
}
