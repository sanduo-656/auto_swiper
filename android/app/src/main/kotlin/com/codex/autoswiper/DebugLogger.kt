package com.codex.autoswiper

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object DebugLogger {
    private const val PREFS_NAME = "auto_swiper_debug"
    private const val KEY_ENABLED = "enabled"
    private const val FILE_NAME = "auto_swiper_debug.log"
    private val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    @Volatile
    private var appContext: Context? = null

    @Volatile
    var enabled: Boolean = false
        private set

    fun initialize(context: Context) {
        appContext = context.applicationContext
        enabled = prefs(context).getBoolean(KEY_ENABLED, false)
    }

    fun setEnabled(context: Context, value: Boolean) {
        initialize(context)
        enabled = value
        prefs(context).edit().putBoolean(KEY_ENABLED, value).apply()
        log("Debug logging ${if (value) "enabled" else "disabled"}")
    }

    fun clear(context: Context) {
        initialize(context)
        logFile(context).writeText("")
        log("Debug log cleared")
    }

    fun path(context: Context): String {
        initialize(context)
        return logFile(context).absolutePath
    }

    fun log(message: String) {
        Log.d("AutoSwipe", message)
        if (!enabled) {
            return
        }
        val context = appContext ?: return
        val line = "${formatter.format(Date())}  $message\n"
        runCatching {
            logFile(context).appendText(line)
        }
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun logFile(context: Context): File =
        File(context.applicationContext.cacheDir, FILE_NAME)
}
