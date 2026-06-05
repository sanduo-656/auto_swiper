package com.codex.autoswiper

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DebugLogger.initialize(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isServiceEnabled" -> result.success(isAccessibilityServiceEnabled())
                "isRunning" -> result.success(AutoSwipeAccessibilityService.isRunning)
                "isControlOverlayEnabled" -> result.success(
                    AutoSwipeAccessibilityService.isControlOverlayEnabled(this),
                )
                "setControlOverlayEnabled" -> {
                    val enabled = call.arguments as? Boolean ?: true
                    result.success(
                        AutoSwipeAccessibilityService.setControlOverlayEnabled(this, enabled),
                    )
                }
                "snapControlOverlay" -> {
                    val edge = call.arguments as? String ?: "right"
                    result.success(AutoSwipeAccessibilityService.snapControlOverlay(this, edge))
                }
                "isDebugLoggingEnabled" -> result.success(DebugLogger.enabled)
                "setDebugLoggingEnabled" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    DebugLogger.setEnabled(this, enabled)
                    result.success(null)
                }
                "clearDebugLog" -> {
                    DebugLogger.clear(this)
                    result.success(null)
                }
                "getDebugLogPath" -> result.success(DebugLogger.path(this))
                "listLaunchableApps" -> result.success(listLaunchableApps())
                "getLaunchPreferences" -> result.success(getLaunchPreferences())
                "saveLaunchPreferences" -> {
                    val arguments = call.arguments as? Map<*, *>
                    saveLaunchPreferences(
                        strategy = arguments?.get("strategy") as? String ?: "previousApp",
                        targetPackageName = arguments?.get("targetPackageName") as? String,
                    )
                    result.success(null)
                }
                "launchApp" -> {
                    val packageName = call.arguments as? String
                    if (packageName.isNullOrBlank()) {
                        result.error("INVALID_PACKAGE", "目标应用包名为空。", null)
                        return@setMethodCallHandler
                    }
                    if (!launchApp(packageName)) {
                        result.error("APP_NOT_FOUND", "无法打开目标应用：$packageName", null)
                        return@setMethodCallHandler
                    }
                    result.success(true)
                }
                "getTapAnchor" -> result.success(
                    AutoSwipeAccessibilityService.tapAnchorState(this),
                )
                "showTapAnchor" -> {
                    if (!isAccessibilityServiceEnabled()) {
                        result.error(
                            "SERVICE_DISABLED",
                            "请先开启随机滑屏无障碍服务，再显示点击锚点。",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    if (!AutoSwipeAccessibilityService.showTapAnchor()) {
                        result.error(
                            "SERVICE_NOT_CONNECTED",
                            "无障碍服务还没有连接成功，请稍后再试。",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(true)
                }
                "hideTapAnchor" -> {
                    result.success(AutoSwipeAccessibilityService.hideTapAnchor())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "moveToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "start" -> {
                    val config = SwipeConfig.fromMap(call.arguments as? Map<*, *>)
                    if (!isAccessibilityServiceEnabled()) {
                        result.error(
                            "SERVICE_DISABLED",
                            "请先开启随机滑屏无障碍服务。",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    AutoSwipeAccessibilityService.start(this, config)
                    result.success(true)
                }
                "startAndLaunch" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val config = SwipeConfig.fromMap(arguments?.get("config") as? Map<*, *>)
                    val strategy = arguments?.get("strategy") as? String ?: "previousApp"
                    val targetPackageName = arguments?.get("targetPackageName") as? String
                    if (!isAccessibilityServiceEnabled()) {
                        result.error(
                            "SERVICE_DISABLED",
                            "请先开启随机滑屏无障碍服务。",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    if (strategy == "selectedApp" && targetPackageName.isNullOrBlank()) {
                        result.error("INVALID_PACKAGE", "请先选择目标 App。", null)
                        return@setMethodCallHandler
                    }
                    AutoSwipeAccessibilityService.start(this, config)
                    if (strategy == "selectedApp") {
                        if (!launchApp(targetPackageName!!)) {
                            AutoSwipeAccessibilityService.stop(this)
                            result.error("APP_NOT_FOUND", "无法打开目标应用：$targetPackageName", null)
                            return@setMethodCallHandler
                        }
                    } else {
                        moveTaskToBack(true)
                    }
                    result.success(true)
                }
                "stop" -> {
                    AutoSwipeAccessibilityService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun listLaunchableApps(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launcherActivities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }
        return launcherActivities
            .asSequence()
            .filter { it.activityInfo.packageName != packageName }
            .map {
                mapOf(
                    "label" to it.loadLabel(packageManager).toString(),
                    "packageName" to it.activityInfo.packageName,
                )
            }
            .distinctBy { it["packageName"] }
            .sortedWith(
                compareBy<Map<String, String>> { it["label"]?.lowercase() }
                    .thenBy { it["packageName"] },
            )
            .toList()
    }

    private fun getLaunchPreferences(): Map<String, String> {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val targetPackageName = prefs.getString(KEY_TARGET_PACKAGE_NAME, null)
        return buildMap {
            put(KEY_LAUNCH_STRATEGY, prefs.getString(KEY_LAUNCH_STRATEGY, "previousApp")!!)
            if (!targetPackageName.isNullOrBlank()) {
                put(KEY_TARGET_PACKAGE_NAME, targetPackageName)
            }
        }
    }

    private fun saveLaunchPreferences(strategy: String, targetPackageName: String?) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putString(KEY_LAUNCH_STRATEGY, strategy)
            .apply {
                if (targetPackageName.isNullOrBlank()) {
                    remove(KEY_TARGET_PACKAGE_NAME)
                } else {
                    putString(KEY_TARGET_PACKAGE_NAME, targetPackageName)
                }
            }
            .apply()
    }

    private fun launchApp(packageName: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        startActivity(launchIntent)
        DebugLogger.log("Launch target app: $packageName")
        return true
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        if (AutoSwipeAccessibilityService.isConnected()) {
            return true
        }
        val expectedName = "$packageName/${AutoSwipeAccessibilityService::class.java.name}"
        val compactName = "$packageName/.${AutoSwipeAccessibilityService::class.java.simpleName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        for (serviceName in splitter) {
            if (
                serviceName.equals(expectedName, ignoreCase = true) ||
                serviceName.equals(compactName, ignoreCase = true)
            ) {
                return true
            }
        }
        return false
    }

    companion object {
        private const val CHANNEL_NAME = "auto_swiper/control"
        private const val PREFS_NAME = "launch_preferences"
        private const val KEY_LAUNCH_STRATEGY = "strategy"
        private const val KEY_TARGET_PACKAGE_NAME = "targetPackageName"
    }
}
