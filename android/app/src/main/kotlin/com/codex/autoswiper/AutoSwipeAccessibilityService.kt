package com.codex.autoswiper

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sqrt
import kotlin.math.sin
import kotlin.random.Random

class AutoSwipeAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val random = Random.Default
    private var windowManager: WindowManager? = null
    private var tapAnchorView: View? = null
    private var tapAnchorParams: WindowManager.LayoutParams? = null
    private var controlOverlayView: View? = null
    private var controlOverlayParams: WindowManager.LayoutParams? = null

    private data class SwipePath(
        val path: Path,
        val control1: TapAnchorPosition,
        val control2: TapAnchorPosition,
    )

    override fun onCreate() {
        super.onCreate()
        DebugLogger.initialize(this)
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        activeService = this
    }

    private val swipeLoop = object : Runnable {
        override fun run() {
            if (!isRunning || activeService !== this@AutoSwipeAccessibilityService) {
                return
            }

            performRandomAction()
            scheduleNextSwipe()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        activeService = this
        restoreRunningState()
        if (TapAnchorStore.isVisible(this)) {
            showTapAnchor()
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No event inspection is needed; the service only dispatches gestures.
    }

    override fun onInterrupt() {
        DebugLogger.log("Accessibility feedback interrupted; keeping auto swipe state.")
    }

    override fun onDestroy() {
        hideTapAnchor()
        hideControlOverlay()
        if (activeService === this && !isRunning) {
            TapAnchorStore.setVisible(this, false)
        }
        isRunning = false
        if (activeService === this) {
            activeService = null
        }
        end()
        super.onDestroy()
    }

    private fun restoreRunningState() {
        if (!AutoSwipeStateStore.shouldRun(this) || isRunning) {
            return
        }
        begin(AutoSwipeStateStore.config(this))
        DebugLogger.log("Auto action restored after accessibility service connected.")
    }

    private fun begin(config: SwipeConfig) {
        activeConfig = config
        isRunning = true
        handler.removeCallbacks(swipeLoop)
        DebugLogger.log("Auto action started: $config")
        if (ControlOverlayStore.isEnabled(this)) {
            showControlOverlay()
        } else {
            hideControlOverlay()
        }
        scheduleNextSwipe(initial = true)
    }

    private fun end() {
        handler.removeCallbacks(swipeLoop)
        hideControlOverlay()
        DebugLogger.log("Auto action stopped.")
    }

    private fun scheduleNextSwipe(initial: Boolean = false) {
        val config = activeConfig
        val baseDelay = random.nextLong(config.minIntervalMs, config.maxIntervalMs + 1)
        val longPauseChance = 0.06f + (config.randomStrength * 0.14f)
        val longPauseMs = if (!initial && random.nextFloat() < longPauseChance) {
            random.nextLong(2_000L, 8_000L)
        } else {
            0L
        }

        handler.postDelayed(swipeLoop, baseDelay + longPauseMs)
        DebugLogger.log("Next action in ${baseDelay + longPauseMs}ms")
    }

    private fun performRandomAction() {
        when (activeConfig.actionPreset) {
            ActionPreset.Fling -> performRandomFling()
            ActionPreset.Tap -> performRandomTap()
            ActionPreset.MultiTap -> performRandomMultiTap()
        }
    }

    private fun performRandomFling() {
        val config = activeConfig
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels.toFloat()
        val height = metrics.heightPixels.toFloat()
        val strength = config.randomStrength.coerceIn(0f, 1f)

        val centerX = width * 0.50f
        val horizontalJitter = width * randomFloat(-0.018f, 0.018f) * (0.35f + strength * 0.65f)
        val baseStartX = (centerX + horizontalJitter).coerceIn(width * 0.44f, width * 0.56f)
        val baseEndX = (baseStartX + width * randomFloat(-0.008f, 0.008f) * strength)
            .coerceIn(width * 0.44f, width * 0.56f)

        val distanceRatio = randomFloat(
            0.24f - strength * 0.03f,
            0.34f + strength * 0.04f,
        ).coerceIn(0.20f, 0.40f)
        val distance = height * distanceRatio
        val verticalAnchor = if (config.direction == SwipeDirection.Up) {
            randomFloat(0.66f, 0.74f)
        } else {
            randomFloat(0.26f, 0.34f)
        }

        val baseStartY = height * verticalAnchor
        val baseEndY = if (config.direction == SwipeDirection.Up) {
            baseStartY - distance
        } else {
            baseStartY + distance
        }.coerceIn(height * 0.16f, height * 0.84f)
        val startPoint = scatterPoint(
            x = baseStartX,
            y = baseStartY.coerceIn(height * 0.16f, height * 0.84f),
            radius = config.scatterRadiusPx,
            width = width,
            height = height,
        )
        val endPoint = scatterPoint(
            x = baseEndX,
            y = baseEndY,
            radius = config.scatterRadiusPx,
            width = width,
            height = height,
        )

        val duration = randomLong(
            (280L - (strength * 35L).roundToInt()).coerceAtLeast(210L),
            520L + (strength * 220L).roundToInt(),
        )

        val swipePath = buildHumanSwipePath(
            startPoint = startPoint,
            endPoint = endPoint,
            direction = config.direction,
            scatterRadiusPx = config.scatterRadiusPx,
            randomStrength = strength,
            width = width,
            height = height,
        )
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(swipePath.path, 0L, duration))
            .build()

        DebugLogger.log(
            "Dispatch swipe ${config.direction}: (${startPoint.x},${startPoint.y}) c1=(${swipePath.control1.x},${swipePath.control1.y}) c2=(${swipePath.control2.x},${swipePath.control2.y}) -> (${endPoint.x},${endPoint.y}), scatter=${config.scatterRadiusPx}px, ${duration}ms",
        )
        dispatchGesture(gesture, null, null)
    }

    private fun buildHumanSwipePath(
        startPoint: TapAnchorPosition,
        endPoint: TapAnchorPosition,
        direction: SwipeDirection,
        scatterRadiusPx: Float,
        randomStrength: Float,
        width: Float,
        height: Float,
    ): SwipePath {
        val distanceY = endPoint.y - startPoint.y
        val sign = if (direction == SwipeDirection.Up) -1f else 1f
        val travel = kotlin.math.abs(distanceY).coerceAtLeast(height * 0.18f)
        val curveJitter = (width * (0.012f + randomStrength * 0.022f))
            .coerceAtLeast(scatterRadiusPx * (0.75f + randomStrength * 0.75f))
        val driftX = randomFloat(-curveJitter, curveJitter)
        val control1 = scatterPoint(
            x = startPoint.x + driftX * 0.45f,
            y = startPoint.y + sign * travel * randomFloat(0.22f, 0.38f),
            radius = scatterRadiusPx * 0.45f,
            width = width,
            height = height,
        )
        val control2 = scatterPoint(
            x = endPoint.x + driftX,
            y = startPoint.y + sign * travel * randomFloat(0.62f, 0.86f),
            radius = scatterRadiusPx * 0.65f,
            width = width,
            height = height,
        )

        val path = Path().apply {
            moveTo(startPoint.x, startPoint.y)
            cubicTo(
                control1.x,
                control1.y,
                control2.x,
                control2.y,
                endPoint.x,
                endPoint.y,
            )
        }
        return SwipePath(
            path = path,
            control1 = control1,
            control2 = control2,
        )
    }

    private fun performRandomTap() {
        val config = activeConfig
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels.toFloat()
        val height = metrics.heightPixels.toFloat()
        val strength = config.randomStrength.coerceIn(0f, 1f)
        val anchor = tapAnchor(width, height, strength)
        val tapPoint = scatterPoint(
            x = anchor.x,
            y = anchor.y,
            radius = config.scatterRadiusPx,
            width = width,
            height = height,
        )
        val duration = randomLong(55L, 115L + (strength * 60L).roundToInt())

        DebugLogger.log(
            "Dispatch tap: (${tapPoint.x},${tapPoint.y}), scatter=${config.scatterRadiusPx}px, ${duration}ms",
        )
        dispatchGesture(buildTapGesture(tapPoint.x, tapPoint.y, 0L, duration), null, null)
    }

    private fun performRandomMultiTap() {
        val config = activeConfig
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels.toFloat()
        val height = metrics.heightPixels.toFloat()
        val strength = config.randomStrength.coerceIn(0f, 1f)
        val anchor = tapAnchor(width, height, strength)
        val x = anchor.x
        val y = anchor.y
        val count = config.multiTapCount
        val builder = GestureDescription.Builder()
        var nextStart = 0L

        repeat(count) { index ->
            val tapPoint = scatterPoint(
                x = x,
                y = y,
                radius = config.scatterRadiusPx,
                width = width,
                height = height,
            )
            val duration = randomLong(45L, 95L)
            val path = Path().apply {
                moveTo(tapPoint.x, tapPoint.y)
            }
            builder.addStroke(GestureDescription.StrokeDescription(path, nextStart, duration))
            if (index < count - 1) {
                nextStart += duration + config.multiTapIntervalMs
            }
        }

        DebugLogger.log(
            "Dispatch multiTap: ($x,$y), count=$count, interval=${config.multiTapIntervalMs}ms, scatter=${config.scatterRadiusPx}px",
        )
        dispatchGesture(builder.build(), null, null)
    }

    private fun buildTapGesture(
        x: Float,
        y: Float,
        startTime: Long,
        duration: Long,
    ): GestureDescription {
        val path = Path().apply {
            moveTo(x, y)
        }
        return GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, startTime, duration))
            .build()
    }

    private fun safeTapX(width: Float, strength: Float): Float {
        return (width * (0.50f + randomFloat(-0.035f, 0.035f) * strength))
            .coerceIn(width * 0.42f, width * 0.58f)
    }

    private fun safeTapY(height: Float, strength: Float): Float {
        return (height * (0.50f + randomFloat(-0.10f, 0.10f) * strength))
            .coerceIn(height * 0.32f, height * 0.68f)
    }

    private fun tapAnchor(width: Float, height: Float, strength: Float): TapAnchorPosition {
        val savedAnchor = TapAnchorStore.get(this)
        if (savedAnchor != null) {
            return TapAnchorPosition(
                x = savedAnchor.x.coerceIn(1f, width - 1f),
                y = savedAnchor.y.coerceIn(1f, height - 1f),
            )
        }
        return TapAnchorPosition(
            x = safeTapX(width, strength),
            y = safeTapY(height, strength),
        )
    }

    private fun scatterPoint(
        x: Float,
        y: Float,
        radius: Float,
        width: Float,
        height: Float,
    ): TapAnchorPosition {
        if (radius <= 0f) {
            return TapAnchorPosition(x.coerceIn(1f, width - 1f), y.coerceIn(1f, height - 1f))
        }

        val angle = random.nextFloat() * 2f * PI.toFloat()
        val distance = sqrt(random.nextFloat()) * radius
        return TapAnchorPosition(
            x = (x + cos(angle) * distance).coerceIn(1f, width - 1f),
            y = (y + sin(angle) * distance).coerceIn(1f, height - 1f),
        )
    }

    private fun showTapAnchor() {
        val manager = windowManager ?: return
        if (tapAnchorView != null) {
            TapAnchorStore.setVisible(this, true)
            return
        }

        val metrics = resources.displayMetrics
        val size = (48f * metrics.density).roundToInt()
        val savedPosition = TapAnchorStore.get(this)
        val anchorX = savedPosition?.x ?: (metrics.widthPixels * 0.5f)
        val anchorY = savedPosition?.y ?: (metrics.heightPixels * 0.5f)
        val params = WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.START or Gravity.TOP
            x = (anchorX - size / 2f).roundToInt()
            y = (anchorY - size / 2f).roundToInt()
        }

        val anchorView = TargetAnchorView(this).apply {
            elevation = 4f * metrics.density
        }

        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0

        anchorView.setOnTouchListener { view, event ->
            val layoutParams = tapAnchorParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = layoutParams.x
                    startY = layoutParams.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val nextX = startX + (event.rawX - downRawX).roundToInt()
                    val nextY = startY + (event.rawY - downRawY).roundToInt()
                    layoutParams.x = nextX.coerceIn(0, metrics.widthPixels - size)
                    layoutParams.y = nextY.coerceIn(0, metrics.heightPixels - size)
                    manager.updateViewLayout(view, layoutParams)
                    saveAnchorFromParams(layoutParams, size)
                    true
                }
                MotionEvent.ACTION_UP,
                MotionEvent.ACTION_CANCEL,
                -> {
                    saveAnchorFromParams(layoutParams, size)
                    true
                }
                else -> false
            }
        }

        manager.addView(anchorView, params)
        tapAnchorView = anchorView
        tapAnchorParams = params
        TapAnchorStore.setVisible(this, true)
        saveAnchorFromParams(params, size)
        DebugLogger.log("Tap anchor shown at (${params.x + size / 2},${params.y + size / 2})")
    }

    private fun hideTapAnchor() {
        val view = tapAnchorView ?: return
        windowManager?.removeView(view)
        tapAnchorView = null
        tapAnchorParams = null
        DebugLogger.log("Tap anchor hidden.")
    }

    private fun showControlOverlay() {
        val manager = windowManager ?: return
        if (controlOverlayView != null) {
            return
        }

        val metrics = resources.displayMetrics
        val density = metrics.density
        val width = (116f * density).roundToInt()
        val height = (44f * density).roundToInt()
        val savedPosition = ControlOverlayStore.get(this)
        val params = WindowManager.LayoutParams(
            width,
            height,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.START or Gravity.TOP
            x = savedPosition?.x?.roundToInt()
                ?: (metrics.widthPixels - width - (12f * density).roundToInt())
            y = savedPosition?.y?.roundToInt()
                ?: (metrics.heightPixels * 0.40f).roundToInt()
            x = x.coerceIn(0, metrics.widthPixels - width)
            y = y.coerceIn(0, metrics.heightPixels - height)
        }

        val overlayView = RunningControlOverlayView(this).apply {
            elevation = 6f * density
        }

        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0
        var dragged = false
        val touchSlop = 8f * density

        overlayView.setOnTouchListener { view, event ->
            val layoutParams = controlOverlayParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = layoutParams.x
                    startY = layoutParams.y
                    dragged = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - downRawX
                    val deltaY = event.rawY - downRawY
                    if (!dragged && kotlin.math.hypot(deltaX, deltaY) >= touchSlop) {
                        dragged = true
                    }
                    if (dragged) {
                        layoutParams.x = (startX + deltaX.roundToInt())
                            .coerceIn(0, metrics.widthPixels - width)
                        layoutParams.y = (startY + deltaY.roundToInt())
                            .coerceIn(0, metrics.heightPixels - height)
                        manager.updateViewLayout(view, layoutParams)
                        ControlOverlayStore.save(this, layoutParams.x.toFloat(), layoutParams.y.toFloat())
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (dragged) {
                        ControlOverlayStore.save(this, layoutParams.x.toFloat(), layoutParams.y.toFloat())
                    } else if (event.x < view.width * 0.52f) {
                        stop(this)
                        openMainActivity()
                    } else {
                        stop(this)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    ControlOverlayStore.save(this, layoutParams.x.toFloat(), layoutParams.y.toFloat())
                    true
                }
                else -> false
            }
        }

        manager.addView(overlayView, params)
        controlOverlayView = overlayView
        controlOverlayParams = params
        ControlOverlayStore.save(this, params.x.toFloat(), params.y.toFloat())
        DebugLogger.log("Running control overlay shown at (${params.x},${params.y})")
    }

    private fun hideControlOverlay() {
        val view = controlOverlayView ?: return
        windowManager?.removeView(view)
        controlOverlayView = null
        controlOverlayParams = null
        DebugLogger.log("Running control overlay hidden.")
    }

    private fun openMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(intent)
        DebugLogger.log("Main activity opened from running control overlay.")
    }

    private fun saveAnchorFromParams(params: WindowManager.LayoutParams, size: Int) {
        TapAnchorStore.save(
            context = this,
            x = params.x + size / 2f,
            y = params.y + size / 2f,
        )
    }

    private fun randomFloat(min: Float, max: Float): Float {
        return min + random.nextFloat() * (max - min)
    }

    private fun randomLong(min: Long, max: Long): Long {
        return random.nextLong(min, max + 1)
    }

    companion object {
        private var activeService: AutoSwipeAccessibilityService? = null
        private var activeConfig = SwipeConfig(
            minIntervalMs = 3_000L,
            maxIntervalMs = 8_000L,
            direction = SwipeDirection.Up,
            actionPreset = ActionPreset.Fling,
            randomStrength = 0.65f,
            scatterRadiusPx = 28f,
            multiTapCount = 3,
            multiTapIntervalMs = 100L,
        )

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context, config: SwipeConfig) {
            activeConfig = config
            AutoSwipeStateStore.saveRunning(context, config)
            activeService?.hideTapAnchor()
            activeService?.let { TapAnchorStore.setVisible(it, false) }
            activeService?.begin(config)
        }

        fun stop(context: Context) {
            AutoSwipeStateStore.saveStopped(context)
            isRunning = false
            activeService?.end()
        }

        fun setControlOverlayEnabled(context: Context, enabled: Boolean): Boolean {
            ControlOverlayStore.setEnabled(context, enabled)
            val service = activeService
            if (service != null && isRunning) {
                if (enabled) {
                    service.showControlOverlay()
                } else {
                    service.hideControlOverlay()
                }
            }
            return true
        }

        fun snapControlOverlay(context: Context, edge: String): Boolean {
            if (edge != "left" && edge != "right") {
                return false
            }
            ControlOverlayStore.saveEdge(context, edge)
            val service = activeService
            return if (service?.controlOverlayView != null) {
                service.snapControlOverlay(edge)
            } else {
                true
            }
        }

        fun isControlOverlayEnabled(context: Context): Boolean {
            return ControlOverlayStore.isEnabled(context)
        }

        fun isConnected(): Boolean {
            return activeService != null
        }

        fun showTapAnchor(): Boolean {
            val service = activeService ?: return false
            service.showTapAnchor()
            return true
        }

        fun hideTapAnchor(): Boolean {
            val service = activeService ?: return false
            service.hideTapAnchor()
            TapAnchorStore.setVisible(service, false)
            return true
        }

        fun tapAnchorState(context: android.content.Context): Map<String, Any?> {
            val position = TapAnchorStore.get(context)
            return mapOf(
                "visible" to (activeService?.tapAnchorView != null || TapAnchorStore.isVisible(context)),
                "hasPosition" to (position != null),
                "x" to position?.x,
                "y" to position?.y,
            )
        }
    }

    private fun snapControlOverlay(edge: String): Boolean {
        val manager = windowManager ?: return false
        val view = controlOverlayView ?: return false
        val params = controlOverlayParams ?: return false
        val metrics = resources.displayMetrics
        val density = metrics.density
        val padding = (12f * density).roundToInt()
        params.x = if (edge == "left") {
            padding
        } else {
            metrics.widthPixels - params.width - padding
        }.coerceIn(0, metrics.widthPixels - params.width)
        params.y = params.y.coerceIn(0, metrics.heightPixels - params.height)
        manager.updateViewLayout(view, params)
        ControlOverlayStore.save(this, params.x.toFloat(), params.y.toFloat())
        DebugLogger.log("Running control overlay snapped to $edge at (${params.x},${params.y})")
        return true
    }

    private class RunningControlOverlayView(context: android.content.Context) : View(context) {
        private val density = resources.displayMetrics.density
        private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(232, 20, 24, 32)
            style = Paint.Style.FILL
        }
        private val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(90, 255, 255, 255)
            strokeWidth = 1f * density
        }
        private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            strokeWidth = 2f * density
        }
        private val stopPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(248, 113, 113)
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            strokeWidth = 2.2f * density
        }
        private val statusPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(34, 197, 94)
            style = Paint.Style.FILL
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val radius = height / 2f
            canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), radius, radius, backgroundPaint)

            val dividerX = width * 0.52f
            canvas.drawLine(dividerX, height * 0.24f, dividerX, height * 0.76f, dividerPaint)
            canvas.drawCircle(14f * density, height / 2f, 3.8f * density, statusPaint)

            val appCenterX = width * 0.31f
            val centerY = height / 2f
            val arrowSize = 7.5f * density
            canvas.drawLine(
                appCenterX - arrowSize * 0.55f,
                centerY,
                appCenterX + arrowSize * 0.55f,
                centerY,
                iconPaint,
            )
            canvas.drawLine(
                appCenterX - arrowSize * 0.10f,
                centerY - arrowSize * 0.48f,
                appCenterX + arrowSize * 0.55f,
                centerY,
                iconPaint,
            )
            canvas.drawLine(
                appCenterX - arrowSize * 0.10f,
                centerY + arrowSize * 0.48f,
                appCenterX + arrowSize * 0.55f,
                centerY,
                iconPaint,
            )
            canvas.drawRoundRect(
                appCenterX - 12f * density,
                centerY - 10f * density,
                appCenterX + 12f * density,
                centerY + 10f * density,
                4f * density,
                4f * density,
                iconPaint,
            )

            val stopCenterX = width * 0.76f
            val stopSize = 7.5f * density
            canvas.drawLine(
                stopCenterX - stopSize,
                centerY - stopSize,
                stopCenterX + stopSize,
                centerY + stopSize,
                stopPaint,
            )
            canvas.drawLine(
                stopCenterX + stopSize,
                centerY - stopSize,
                stopCenterX - stopSize,
                centerY + stopSize,
                stopPaint,
            )
        }
    }

    private class TargetAnchorView(context: android.content.Context) : View(context) {
        private val density = resources.displayMetrics.density
        private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(238, 18, 18, 18)
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = 2.2f * density
        }
        private val thinPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(220, 18, 18, 18)
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = 1.1f * density
        }
        private val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(210, 18, 18)
            style = Paint.Style.STROKE
            strokeWidth = 1.4f * density
        }
        private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(72, 255, 255, 255)
            style = Paint.Style.STROKE
            strokeWidth = 3f * density
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val centerX = width / 2f
            val centerY = height / 2f
            val radius = width.coerceAtMost(height) / 2f
            val outerRadius = radius - 4f * density
            val middleRadius = radius * 0.34f
            val innerRadius = radius * 0.17f
            val tickGap = radius * 0.42f
            val tickEnd = radius - 2f * density

            canvas.drawCircle(centerX, centerY, outerRadius, shadowPaint)
            canvas.drawCircle(centerX, centerY, outerRadius, ringPaint)
            canvas.drawCircle(centerX, centerY, middleRadius, ringPaint)
            canvas.drawCircle(centerX, centerY, innerRadius, ringPaint)

            canvas.drawLine(centerX, centerY - tickEnd, centerX, centerY - tickGap, thinPaint)
            canvas.drawLine(centerX, centerY + tickGap, centerX, centerY + tickEnd, thinPaint)
            canvas.drawLine(centerX - tickEnd, centerY, centerX - tickGap, centerY, thinPaint)
            canvas.drawLine(centerX + tickGap, centerY, centerX + tickEnd, centerY, thinPaint)
            canvas.drawCircle(centerX, centerY, 3.8f * density, centerPaint)
        }
    }
}
