package com.abairt.listen.ui

/** 83_000 -> "1:23", 3_725_000 -> "1:02:05". */
fun formatTime(ms: Long): String {
    val totalSeconds = (ms.coerceAtLeast(0)) / 1000
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, seconds) else "%d:%02d".format(minutes, seconds)
}

val PLAYBACK_SPEEDS = listOf(0.5f, 0.65f, 0.8f, 0.9f, 1f, 1.15f, 1.3f)

fun formatSpeed(speed: Float): String = "%s×".format(("%.2f".format(speed)).trimEnd('0').trimEnd('.'))
