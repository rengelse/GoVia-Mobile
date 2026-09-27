package no.govia.mobile.car

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View

/**
 * Compact GoVia cockpit overlay drawn in physical surface coordinates.
 * Do not size this UI in Android dp: projected Android Auto surfaces can report
 * densities that make a perfectly reasonable dp card consume half the map.
 */
internal class GoViaCarCockpitOverlayView(context: Context) : View(context) {
    data class NavigationState(
        val distance: String = "",
        val instruction: String = "Følg ruten",
        val road: String = "",
        val tripName: String = "",
        val arrival: String = "",
        val remaining: String = "",
        val poi: String? = null,
        val direction: Direction = Direction.STRAIGHT,
    )

    data class RecordingState(
        val elapsed: String = "00:00",
        val distance: String = "0 m",
        val gpsActive: Boolean = false,
    )

    enum class Mode { NAVIGATION, RECORDING }
    enum class Direction { LEFT, RIGHT, STRAIGHT, ROUNDABOUT, UTURN }

    var darkMode: Boolean = true
        set(value) { field = value; invalidate() }
    var mode: Mode = Mode.NAVIGATION
        set(value) { field = value; invalidate() }
    var navigationState: NavigationState = NavigationState()
        set(value) { field = value; invalidate() }
    var recordingState: RecordingState = RecordingState()
        set(value) { field = value; invalidate() }

    private val panel = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val primary = Paint(Paint.ANTI_ALIAS_FLAG)
    private val secondary = Paint(Paint.ANTI_ALIAS_FLAG)
    private val accent = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ORANGE }
    private val red = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = RED }
    private val green = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = GREEN }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) return
        configurePalette()
        when (mode) {
            Mode.NAVIGATION -> drawNavigation(canvas)
            Mode.RECORDING -> drawRecording(canvas)
        }
    }

    private fun configurePalette() {
        panel.color = if (darkMode) Color.argb(232, 7, 13, 20) else Color.argb(239, 250, 250, 248)
        stroke.color = if (darkMode) Color.argb(238, 255, 126, 22) else Color.argb(238, 226, 96, 8)
        stroke.strokeWidth = px(1.5f)
        primary.color = if (darkMode) Color.WHITE else Color.rgb(20, 27, 33)
        secondary.color = if (darkMode) Color.rgb(203, 211, 221) else Color.rgb(73, 83, 94)
    }

    private fun drawNavigation(canvas: Canvas) {
        val u = scaleUnit()
        val margin = 18f * u
        val cardW = (width * 0.29f).coerceIn(285f * u, 365f * u)
        val cardH = (height * 0.285f).coerceIn(146f * u, 178f * u)
        val left = margin
        val top = margin
        val rect = RectF(left, top, left + cardW, top + cardH)
        roundPanel(canvas, rect, 18f * u, border = true)

        val iconBox = RectF(left + 15f*u, top + 14f*u, left + 69f*u, top + 72f*u)
        drawTurnIcon(canvas, iconBox, navigationState.direction, u)

        primary.textSize = 27f * u
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        val distance = navigationState.distance.ifBlank { "—" }
        canvas.drawText(distance, left + 80f*u, top + 40f*u, primary)

        secondary.textSize = 15f * u
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText(
            ellipsize(navigationState.instruction.ifBlank { "Følg ruten" }, 29),
            left + 80f*u,
            top + 64f*u,
            secondary,
        )

        if (navigationState.road.isNotBlank()) {
            primary.textSize = 17f * u
            primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
            canvas.drawText(ellipsize(navigationState.road, 26), left + 80f*u, top + 89f*u, primary)
        }

        val dividerY = top + cardH - 49f*u
        stroke.color = if (darkMode) Color.argb(105, 210, 220, 230) else Color.argb(82, 35, 45, 55)
        stroke.strokeWidth = 1f*u
        canvas.drawLine(left + 18f*u, dividerY, left + cardW - 18f*u, dividerY, stroke)

        primary.textSize = 14f*u
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        if (navigationState.tripName.isNotBlank()) {
            canvas.drawText(ellipsize(navigationState.tripName, 29), left + 20f*u, dividerY + 20f*u, primary)
        }
        secondary.textSize = 13f*u
        secondary.typeface = android.graphics.Typeface.DEFAULT
        val summary = listOf(navigationState.remaining, navigationState.arrival)
            .filter { it.isNotBlank() }
            .joinToString(" · ")
        canvas.drawText(ellipsize(summary, 34), left + 20f*u, dividerY + 40f*u, secondary)

        navigationState.poi?.takeIf { it.isNotBlank() }?.let { poi ->
            val poiTop = rect.bottom + 10f*u
            val poiH = 58f*u
            val poiRect = RectF(left, poiTop, left + cardW, poiTop + poiH)
            roundPanel(canvas, poiRect, 16f*u, border = true)
            accent.style = Paint.Style.STROKE
            accent.strokeWidth = 3f*u
            canvas.drawCircle(left + 32f*u, poiTop + poiH/2f, 15f*u, accent)
            accent.style = Paint.Style.FILL
            secondary.textSize = 13f*u
            canvas.drawText("POI nærmer seg", left + 55f*u, poiTop + 23f*u, secondary)
            primary.textSize = 16f*u
            primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
            canvas.drawText(ellipsize(poi, 28), left + 55f*u, poiTop + 44f*u, primary)
        }
    }

    private fun drawRecording(canvas: Canvas) {
        val u = scaleUnit()
        val margin = 18f*u
        val cardW = (width * 0.255f).coerceIn(250f*u, 325f*u)
        val cardH = 82f*u
        val rect = RectF(margin, margin, margin + cardW, margin + cardH)
        roundPanel(canvas, rect, 18f*u, border = false)

        red.style = Paint.Style.FILL
        canvas.drawCircle(margin + 31f*u, margin + 29f*u, 8f*u, red)
        primary.textSize = 19f*u
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText("REC", margin + 50f*u, margin + 35f*u, primary)

        secondary.textSize = 14f*u
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText("${recordingState.elapsed}  ·  ${recordingState.distance}", margin + 50f*u, margin + 61f*u, secondary)

        val gpsLabel = if (recordingState.gpsActive) "GPS aktiv" else "Venter på GPS"
        val gpsW = 128f*u
        val gpsRect = RectF(margin, height - 58f*u, margin + gpsW, height - 18f*u)
        roundPanel(canvas, gpsRect, 13f*u, border = false)
        canvas.drawCircle(margin + 18f*u, height - 38f*u, 6f*u, if (recordingState.gpsActive) green else secondary)
        primary.textSize = 14f*u
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText(gpsLabel, margin + 33f*u, height - 33f*u, primary)
    }

    private fun drawTurnIcon(canvas: Canvas, box: RectF, direction: Direction, u: Float) {
        accent.color = ORANGE
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = 8f*u
        accent.strokeCap = Paint.Cap.ROUND
        accent.strokeJoin = Paint.Join.ROUND
        val path = Path()
        when (direction) {
            Direction.RIGHT -> {
                path.moveTo(box.left + 18f*u, box.bottom - 8f*u)
                path.lineTo(box.left + 18f*u, box.centerY())
                path.quadTo(box.left + 18f*u, box.top + 10f*u, box.left + 46f*u, box.top + 10f*u)
                path.lineTo(box.right - 10f*u, box.top + 10f*u)
                canvas.drawPath(path, accent)
                drawArrowHead(canvas, box.right - 10f*u, box.top + 10f*u, 0f, u)
            }
            Direction.LEFT -> {
                path.moveTo(box.right - 18f*u, box.bottom - 8f*u)
                path.lineTo(box.right - 18f*u, box.centerY())
                path.quadTo(box.right - 18f*u, box.top + 10f*u, box.left + 20f*u, box.top + 10f*u)
                canvas.drawPath(path, accent)
                drawArrowHead(canvas, box.left + 20f*u, box.top + 10f*u, 180f, u)
            }
            Direction.ROUNDABOUT -> {
                val cx = box.centerX(); val cy = box.centerY()
                canvas.drawCircle(cx, cy, 22f*u, accent)
                drawArrowHead(canvas, cx + 22f*u, cy, 0f, u)
            }
            Direction.UTURN -> {
                path.moveTo(box.centerX()+15f*u, box.bottom-8f*u)
                path.lineTo(box.centerX()+15f*u, box.top+28f*u)
                path.quadTo(box.centerX()+15f*u, box.top+6f*u, box.centerX()-8f*u, box.top+6f*u)
                path.quadTo(box.centerX()-30f*u, box.top+6f*u, box.centerX()-30f*u, box.top+28f*u)
                canvas.drawPath(path, accent)
                drawArrowHead(canvas, box.centerX()-30f*u, box.top+28f*u, 90f, u)
            }
            Direction.STRAIGHT -> {
                path.moveTo(box.centerX(), box.bottom - 8f*u)
                path.lineTo(box.centerX(), box.top + 13f*u)
                canvas.drawPath(path, accent)
                drawArrowHead(canvas, box.centerX(), box.top + 13f*u, -90f, u)
            }
        }
        accent.style = Paint.Style.FILL
    }

    private fun drawArrowHead(canvas: Canvas, x: Float, y: Float, degrees: Float, u: Float) {
        canvas.save()
        canvas.rotate(degrees, x, y)
        val p = Path().apply {
            moveTo(x + 13f*u, y)
            lineTo(x - 3f*u, y - 10f*u)
            lineTo(x - 3f*u, y + 10f*u)
            close()
        }
        canvas.drawPath(p, accent)
        canvas.restore()
    }

    private fun roundPanel(canvas: Canvas, rect: RectF, radius: Float, border: Boolean) {
        canvas.drawRoundRect(rect, radius, radius, panel)
        if (border) {
            stroke.color = if (darkMode) ORANGE else Color.rgb(220, 98, 8)
            stroke.strokeWidth = px(1.4f)
            canvas.drawRoundRect(rect, radius, radius, stroke)
        }
    }

    private fun ellipsize(value: String, maxChars: Int): String =
        if (value.length <= maxChars) value else value.take((maxChars - 1).coerceAtLeast(1)) + "…"

    private fun scaleUnit(): Float = kotlin.math.min(width / 1280f, height / 600f).coerceIn(0.78f, 1.35f)
    private fun px(value: Float): Float = value * scaleUnit()

    companion object {
        private val ORANGE = Color.rgb(255, 126, 22)
        private val RED = Color.rgb(239, 55, 55)
        private val GREEN = Color.rgb(52, 211, 153)
    }
}
