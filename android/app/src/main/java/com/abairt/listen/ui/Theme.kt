package com.abairt.listen.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Green = Color(0xFF1B6B4A)
private val LightGreen = Color(0xFF7AD7A8)

private val Light = lightColorScheme(
    primary = Green,
    primaryContainer = Color(0xFFC2EDD6),
    onPrimaryContainer = Color(0xFF002114),
    background = Color(0xFFFBFDF8),
    surface = Color(0xFFFBFDF8),
)

// True black behind everything: restful in a dark room, and off on an OLED screen.
private val Dark = darkColorScheme(
    primary = LightGreen,
    onPrimary = Color(0xFF00391F),
    primaryContainer = Color(0xFF0F3D2A),
    onPrimaryContainer = Color(0xFFC2EDD6),
    background = Color.Black,
    surface = Color.Black,
    surfaceVariant = Color(0xFF1A1C1A),
    surfaceContainer = Color(0xFF0E100E),
)

@Composable
fun AbairtTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Dark else Light, content = content)
}
