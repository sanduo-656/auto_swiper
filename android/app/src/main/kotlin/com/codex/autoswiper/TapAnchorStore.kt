package com.codex.autoswiper

import android.content.Context

data class TapAnchorPosition(
    val x: Float,
    val y: Float,
)

object TapAnchorStore {
    private const val PREFS_NAME = "tap_anchor"
    private const val KEY_HAS_POSITION = "has_position"
    private const val KEY_VISIBLE = "visible"
    private const val KEY_X = "x"
    private const val KEY_Y = "y"

    fun save(context: Context, x: Float, y: Float) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_HAS_POSITION, true)
            .putFloat(KEY_X, x)
            .putFloat(KEY_Y, y)
            .apply()
    }

    fun setVisible(context: Context, visible: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_VISIBLE, visible)
            .apply()
    }

    fun isVisible(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_VISIBLE, false)
    }

    fun get(context: Context): TapAnchorPosition? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_HAS_POSITION, false)) {
            return null
        }
        return TapAnchorPosition(
            x = prefs.getFloat(KEY_X, 0f),
            y = prefs.getFloat(KEY_Y, 0f),
        )
    }
}
