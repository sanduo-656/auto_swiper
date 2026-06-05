package com.codex.autoswiper

data class SwipeConfig(
    val minIntervalMs: Long,
    val maxIntervalMs: Long,
    val direction: SwipeDirection,
    val actionPreset: ActionPreset,
    val randomStrength: Float,
    val scatterRadiusPx: Float,
    val multiTapCount: Int,
    val multiTapIntervalMs: Long,
) {
    companion object {
        fun fromMap(arguments: Map<*, *>?): SwipeConfig {
            val minIntervalMs = arguments.longValue("minIntervalMs", 3_000L)
                .coerceIn(1_000L, 60_000L)
            val maxIntervalMs = arguments.longValue("maxIntervalMs", 8_000L)
                .coerceIn(minIntervalMs, 120_000L)
            val direction = SwipeDirection.fromName(arguments?.get("direction") as? String)
            val actionPreset = ActionPreset.fromName(arguments?.get("actionPreset") as? String)
            val randomStrength = arguments.floatValue("randomStrength", 0.65f)
                .coerceIn(0f, 1f)
            val scatterRadiusPx = arguments.floatValue("scatterRadiusPx", 28f)
                .coerceIn(0f, 200f)
            val multiTapCount = arguments.intValue("multiTapCount", 3)
                .coerceIn(2, 20)
            val multiTapIntervalMs = arguments.longValue("multiTapIntervalMs", 100L)
                .coerceIn(50L, 1_000L)

            return SwipeConfig(
                minIntervalMs = minIntervalMs,
                maxIntervalMs = maxIntervalMs,
                direction = direction,
                actionPreset = actionPreset,
                randomStrength = randomStrength,
                scatterRadiusPx = scatterRadiusPx,
                multiTapCount = multiTapCount,
                multiTapIntervalMs = multiTapIntervalMs,
            )
        }

        private fun Map<*, *>?.longValue(key: String, fallback: Long): Long {
            return when (val value = this?.get(key)) {
                is Number -> value.toLong()
                is String -> value.toLongOrNull() ?: fallback
                else -> fallback
            }
        }

        private fun Map<*, *>?.floatValue(key: String, fallback: Float): Float {
            return when (val value = this?.get(key)) {
                is Number -> value.toFloat()
                is String -> value.toFloatOrNull() ?: fallback
                else -> fallback
            }
        }

        private fun Map<*, *>?.intValue(key: String, fallback: Int): Int {
            return when (val value = this?.get(key)) {
                is Number -> value.toInt()
                is String -> value.toIntOrNull() ?: fallback
                else -> fallback
            }
        }
    }
}

enum class ActionPreset {
    Fling,
    Tap,
    MultiTap;

    companion object {
        fun fromName(name: String?): ActionPreset {
            return when (name?.lowercase()) {
                "tap" -> Tap
                "multitap" -> MultiTap
                else -> Fling
            }
        }
    }
}

enum class SwipeDirection {
    Up,
    Down;

    companion object {
        fun fromName(name: String?): SwipeDirection {
            return when (name?.lowercase()) {
                "down" -> Down
                else -> Up
            }
        }
    }
}
