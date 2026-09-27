package no.govia.mobile.car

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import java.util.Locale

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
        set(value) {
            field = value
            invalidate()
        }
    var mode: Mode = Mode.NAVIGATION
        set(value) {
            field = value
            invalidate()
        }
    var navigationState: NavigationState = NavigationState()
        set(value) {
            field = value
            invalidate()
        }
    var recordingState: RecordingState = RecordingState()
        set(value) {
            field = value
            invalidate()
        }

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
        panel.color = if (darkMode) Color.argb(224, 8, 14, 22) else Color.argb(235, 250, 250, 248)
        stroke.color = if (darkMode) Color.argb(225, 255, 135, 30) else Color.argb(235, 230, 102, 10)
        stroke.strokeWidth = dp(1.5f)
        primary.color = if (darkMode) Color.WHITE else Color.rgb(22, 28, 34)
        secondary.color = if (darkMode) Color.rgb(198, 207, 219) else Color.rgb(78, 88, 98)
    }

    private fun drawNavigation(canvas: Canvas) {
        val margin = dp(14f)
        val availableW = width.toFloat()
        val cardW = (availableW * 0.40f).coerceIn(dp(265f), dp(360f))
        val cardH = (height * 0.48f).coerceIn(dp(128f), dp(178f))
        val left = margin
        val top = margin
        val rect = RectF(left, top, left + cardW, top + cardH)
        roundPanel(canvas, rect, dp(17f), border = true)

        val iconBox = RectF(left + dp(15f), top + dp(18f), left + dp(78f), top + dp(82f))
        drawTurnIcon(canvas, iconBox, navigationState.direction)

        primary.textSize = sp(26f)
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText(navigationState.distance.ifBlank { "—" }, left + dp(92f), top + dp(46f), primary)

        secondary.textSize = sp(15.5f)
        secondary.typeface = android.graphics.Typeface.DEFAULT
        val instruction = navigationState.instruction.ifBlank { "Følg ruten" }
        canvas.drawText(ellipsize(instruction, 31), left + dp(92f), top + dp(70f), secondary)

        primary.textSize = sp(17f)
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        if (navigationState.road.isNotBlank()) {
            canvas.drawText(ellipsize(navigationState.road, 27), left + dp(92f), top + dp(94f), primary)
        }

        val dividerY = top + cardH - dp(48f)
        stroke.color = if (darkMode) Color.argb(110, 210, 220, 230) else Color.argb(90, 35, 45, 55)
        stroke.strokeWidth = dp(1f)
        canvas.drawLine(left + dp(18f), dividerY, left + cardW - dp(18f), dividerY, stroke)
        secondary.textSize = sp(14f)
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText(ellipsize(navigationState.tripName, 30), left + dp(20f), dividerY + dp(26f), secondary)
        val summary = listOf(navigationState.remaining, navigationState.arrival).filter { it.isNotBlank() }.joinToString(" · ")
        canvas.drawText(ellipsize(summary, 32), left + dp(20f), dividerY + dp(44f), secondary)

        navigationState.poi?.takeIf { it.isNotBlank() }?.let { poi ->
            val poiTop = rect.bottom + dp(10f)
            val poiH = dp(60f)
            val poiRect = RectF(left, poiTop, left + cardW, poiTop + poiH)
            roundPanel(canvas, poiRect, dp(15f), border = true)
            accent.style = Paint.Style.STROKE
            accent.strokeWidth = dp(3f)
            canvas.drawCircle(left + dp(31f), poiTop + poiH / 2f, dp(17f), accent)
            accent.style = Paint.Style.FILL
            secondary.textSize = sp(12f)
            canvas.drawText("POI nærmer seg", left + dp(58f), poiTop + dp(23f), secondary)
            primary.textSize = sp(17f)
            primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
            canvas.drawText(ellipsize(poi, 31), left + dp(58f), poiTop + dp(45f), primary)
        }
    }

    private fun drawRecording(canvas: Canvas) {
        val margin = dp(14f)
        val cardW = (width * 0.38f).coerceIn(dp(250f), dp(340f))
        val cardH = dp(86f)
        val rect = RectF(margin, margin, margin + cardW, margin + cardH)
        roundPanel(canvas, rect, dp(17f), border = false)

        red.style = Paint.Style.STROKE
        red.strokeWidth = dp(4f)
        canvas.drawCircle(margin + dp(39f), margin + dp(42f), dp(24f), red)
        red.style = Paint.Style.FILL
        canvas.drawCircle(margin + dp(39f), margin + dp(42f), dp(13f), red)

        primary.textSize = sp(21f)
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText("Opptak pågår", margin + dp(78f), margin + dp(36f), primary)
        secondary.textSize = sp(15f)
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText("Tid ${recordingState.elapsed} · ${recordingState.distance}", margin + dp(78f), margin + dp(62f), secondary)

        val gpsRect = RectF(margin, height - dp(68f), margin + dp(154f), height - dp(18f))
        roundPanel(canvas, gpsRect, dp(14f), border = false)
        val statusPaint = if (recordingState.gpsActive) green else secondary
        canvas.drawCircle(margin + dp(24f), height - dp(43f), dp(7f), statusPaint)
        primary.textSize = sp(15f)
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText(if (recordingState.gpsActive) "GPS aktiv" else "Venter på GPS", margin + dp(42f), height - dp(37f), primary)
    }

    private fun drawTurnIcon(canvas: Canvas, box: RectF, direction: Direction) {
        accent.color = ORANGE
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = dp(8f)
        accent.strokeCap = Paint.Cap.ROUND
        accent.strokeJoin = Paint.Join.ROUND
        val path = Path()
        when (direction) {
            Direction.RIGHT -> {
                path.moveTo(box.left + dp(20f), box.bottom - dp(8f))
                path.lineTo(box.left + dp(20f), box.centerY())
                path.quadTo(box.left + dp(20f), box.top + dp(10f), box.left + dp(48f), box.top + dp(10f))
                path.lineTo(box.right - dp(10f), box.top + dp(10f))
                canvas.drawPath(path, accent)
                drawArrowHead(canvas, box.right - dp(10f), box.top + dp(10f), 0f)
            }
            Direction.LEFT -> {
                path.moveTo(box.right - dp(20f), box.bottom - dp(8f))
                path.lineTo(box.right - dp(20f), box.centerY())
                path.quadTo(box.right - dp(20f), box.top + dp(10f), box.left + dp(20f), box.top + dp(10f))
                canvas.drawPath(path, accent)
                drawArrowHead(canvas, box.left + dp(20f), box.top + dp(10f), 180f)
            }
            else -> {
                path.moveTo(box.centerX(), box.bottom - dp(8f))
                path.lineTo(box.centerX(), box.top + dp(13f))
                canvas.drawPath(path, accent)
                drawArrowHead(canvas, box.centerX(), box.top + dp(13f), -90f)
            }
        }
        accent.style = Paint.Style.FILL
    }

    private fun drawArrowHead(canvas: Canvas, x: Float, y: Float, degrees: Float) {
        canvas.save()
        canvas.rotate(degrees, x, y)
        val p = Path().apply {
            moveTo(x + dp(13f), y)
            lineTo(x - dp(3f), y - dp(10f))
            lineTo(x - dp(3f), y + dp(10f))
            close()
        }
        canvas.drawPath(p, accent)
        canvas.restore()
    }

    private fun roundPanel(canvas: Canvas, rect: RectF, radius: Float, border: Boolean) {
        canvas.drawRoundRect(rect, radius, radius, panel)
        if (border) {
            stroke.color = if (darkMode) ORANGE else Color.rgb(220, 98, 8)
            stroke.strokeWidth = dp(1.4f)
            canvas.drawRoundRect(rect, radius, radius, stroke)
        }
    }

    private fun ellipsize(value: String, maxChars: Int): String =
        if (value.length <= maxChars) value else value.take((maxChars - 1).coerceAtLeast(1)) + "…"

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
    private fun sp(value: Float): Float = value * resources.displayMetrics.scaledDensity.coerceAtMost(resources.displayMetrics.density * 1.15f)

    companion object {
        private val ORANGE = Color.rgb(255, 126, 22)
        private val RED = Color.rgb(239, 55, 55)
        private val GREEN = Color.rgb(31, 219, 111)
    }
}
