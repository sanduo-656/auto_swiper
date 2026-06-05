package com.codex.autoswiper

import android.content.Context

object ControlOverlayStore {
    private const val PREFS_NAME = "running_control_overlay"
    private const val KEY_HAS_POSITION = "has_position"
    private const val KEY_X = "x"
    private const val KEY_Y = "y"
    private const val KEY_ENABLED = "enabled"

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
    }

    fun isEnabled(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_ENABLED, true)
    }

    fun save(context: Context, x: Float, y: Float) {
        prefs(context).edit()
            .putBoolean(KEY_HAS_POSITION, true)
            .putFloat(KEY_X, x)
            .putFloat(KEY_Y, y)
            .apply()
    }

    fun saveEdge(context: Context, edge: String) {
        val metrics = context.resources.displayMetrics
        val density = metrics.density
        val width = (116f * density).toInt()
        val padding = (12f * density).toInt()
        val x = if (edge == "left") {
            padding
        } else {
            metrics.widthPixels - width - padding
        }.coerceIn(0, metrics.widthPixels - width)
        val y = (metrics.heightPixels * 0.40f).toInt()
            .coerceIn(0, metrics.heightPixels - (44f * density).toInt())
        save(context, x.toFloat(), y.toFloat())
    }

    fun get(context: Context): TapAnchorPosition? {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_HAS_POSITION, false)) {
            return null
        }
        return TapAnchorPosition(
            x = prefs.getFloat(KEY_X, 0f),
            y = prefs.getFloat(KEY_Y, 0f),
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
