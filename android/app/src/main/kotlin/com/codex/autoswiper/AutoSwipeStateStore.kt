package com.codex.autoswiper

import android.content.Context

object AutoSwipeStateStore {
    private const val PREFS_NAME = "auto_swipe_state"
    private const val KEY_SHOULD_RUN = "should_run"
    private const val KEY_MIN_INTERVAL_MS = "min_interval_ms"
    private const val KEY_MAX_INTERVAL_MS = "max_interval_ms"
    private const val KEY_DIRECTION = "direction"
    private const val KEY_ACTION_PRESET = "action_preset"
    private const val KEY_RANDOM_STRENGTH = "random_strength"
    private const val KEY_SCATTER_RADIUS_PX = "scatter_radius_px"
    private const val KEY_MULTI_TAP_COUNT = "multi_tap_count"
    private const val KEY_MULTI_TAP_INTERVAL_MS = "multi_tap_interval_ms"

    private val defaultConfig = SwipeConfig(
        minIntervalMs = 3_000L,
        maxIntervalMs = 8_000L,
        direction = SwipeDirection.Up,
        actionPreset = ActionPreset.Fling,
        randomStrength = 0.65f,
        scatterRadiusPx = 28f,
        multiTapCount = 3,
        multiTapIntervalMs = 100L,
    )

    fun saveRunning(context: Context, config: SwipeConfig) {
        prefs(context).edit()
            .putBoolean(KEY_SHOULD_RUN, true)
            .putLong(KEY_MIN_INTERVAL_MS, config.minIntervalMs)
            .putLong(KEY_MAX_INTERVAL_MS, config.maxIntervalMs)
            .putString(KEY_DIRECTION, config.direction.name)
            .putString(KEY_ACTION_PRESET, config.actionPreset.name)
            .putFloat(KEY_RANDOM_STRENGTH, config.randomStrength)
            .putFloat(KEY_SCATTER_RADIUS_PX, config.scatterRadiusPx)
            .putInt(KEY_MULTI_TAP_COUNT, config.multiTapCount)
            .putLong(KEY_MULTI_TAP_INTERVAL_MS, config.multiTapIntervalMs)
            .apply()
    }

    fun saveStopped(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_SHOULD_RUN, false)
            .apply()
    }

    fun shouldRun(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_SHOULD_RUN, false)
    }

    fun config(context: Context): SwipeConfig {
        val prefs = prefs(context)
        val minIntervalMs = prefs.getLong(
            KEY_MIN_INTERVAL_MS,
            defaultConfig.minIntervalMs,
        ).coerceIn(1_000L, 60_000L)
        val maxIntervalMs = prefs.getLong(
            KEY_MAX_INTERVAL_MS,
            defaultConfig.maxIntervalMs,
        ).coerceIn(minIntervalMs, 120_000L)

        return SwipeConfig(
            minIntervalMs = minIntervalMs,
            maxIntervalMs = maxIntervalMs,
            direction = SwipeDirection.fromName(prefs.getString(KEY_DIRECTION, null)),
            actionPreset = ActionPreset.fromName(prefs.getString(KEY_ACTION_PRESET, null)),
            randomStrength = prefs.getFloat(
                KEY_RANDOM_STRENGTH,
                defaultConfig.randomStrength,
            ).coerceIn(0f, 1f),
            scatterRadiusPx = prefs.getFloat(
                KEY_SCATTER_RADIUS_PX,
                defaultConfig.scatterRadiusPx,
            ).coerceIn(0f, 200f),
            multiTapCount = prefs.getInt(
                KEY_MULTI_TAP_COUNT,
                defaultConfig.multiTapCount,
            ).coerceIn(2, 20),
            multiTapIntervalMs = prefs.getLong(
                KEY_MULTI_TAP_INTERVAL_MS,
                defaultConfig.multiTapIntervalMs,
            ).coerceIn(50L, 1_000L),
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
