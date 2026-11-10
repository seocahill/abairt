package com.abairt.listen.playback

import androidx.media3.common.ForwardingSimpleBasePlayer
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import com.abairt.listen.data.Line

/**
 * The player as the system shows it. While a line of the transcript is
 * playing, the lock screen, notification, Bluetooth and watch displays show
 * that line (the Irish as the title, the English beneath) in place of the
 * recording's title, so it can be read at a glance without unlocking.
 *
 * Only the player-level metadata changes: the media item keeps the recording's
 * own title, which is what the app's screens show.
 */
@UnstableApi
class LinePlayer(player: Player) : ForwardingSimpleBasePlayer(player) {
    private var line: Line? = null

    /** Shows [line] in place of the title, or the recording's own title for null. */
    fun show(line: Line?) {
        if (line == this.line) return
        this.line = line
        invalidateState()
    }

    override fun getState(): State {
        val state = super.getState()
        val line = line ?: return state
        val index = state.currentMediaItemIndex
        val item = state.playlist.getOrNull(index) ?: return state

        val playlist = state.playlist.toMutableList()
        playlist[index] = item.buildUpon()
            .setMediaMetadata(item.mediaItem.mediaMetadata.showingLine(line))
            .build()
        return state.buildUpon().setPlaylist(playlist).build()
    }
}

/** The recording's metadata with [line] as the title and its English (or the recording's title) beneath. */
fun MediaMetadata.showingLine(line: Line): MediaMetadata = buildUpon()
    .setTitle(line.irish)
    .setArtist(line.translation?.takeIf { it.isNotBlank() } ?: title)
    .build()
