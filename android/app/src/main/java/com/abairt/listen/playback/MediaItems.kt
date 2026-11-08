package com.abairt.listen.playback

import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import com.abairt.listen.data.RecordingSummary

private const val RADIO_ALBUM = "Abairt"

/** What the lock screen, the notification and Bluetooth displays show of a recording. */
fun RecordingSummary.toMediaItem(): MediaItem = MediaItem.Builder()
    .setMediaId(id.toString())
    .setUri(audioUrl)
    .setMediaMetadata(
        MediaMetadata.Builder()
            .setTitle(title)
            .setArtist(dialectRegion)
            .setAlbumTitle(RADIO_ALBUM)
            .setDurationMs((durationSeconds * 1000).toLong())
            .setIsPlayable(true)
            .setIsBrowsable(false)
            .build(),
    )
    .build()
