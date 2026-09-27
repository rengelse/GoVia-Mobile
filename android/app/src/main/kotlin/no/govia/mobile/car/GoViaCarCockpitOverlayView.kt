package no.govia.mobile.car

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View

/** Compact, map-first GoVia overlay for projected Android Auto surfaces. */
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

    data class PreviewState(
        val name: String = "Tur",
        val route: String = "",
        val distance: String = "—",
        val duration: String = "—",
        val poiCount: String = "0",
        val stopCount: String = "0",
    )

    data class RecordingState(
        val elapsed: String = "00:00",
        val distance: String = "0 m",
        val gpsActive: Boolean = false,
    )

    enum class Mode { PREVIEW, NAVIGATION, RECORDING }
    enum class Direction { LEFT, RIGHT, STRAIGHT, ROUNDABOUT, UTURN }

    var darkMode: Boolean = true
        set(value) { field = value; invalidate() }
    var mode: Mode = Mode.NAVIGATION
        set(value) { field = value; invalidate() }
    var navigationState: NavigationState = NavigationState()
        set(value) { field = value; invalidate() }
    var previewState: PreviewState = PreviewState()
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
            Mode.PREVIEW -> drawPreview(canvas)
            Mode.NAVIGATION -> drawNavigation(canvas)
            Mode.RECORDING -> drawRecording(canvas)
        }
    }

    private fun configurePalette() {
        panel.color = if (darkMode) Color.argb(238, 7, 13, 20) else Color.argb(244, 250, 250, 248)
        stroke.color = if (darkMode) Color.argb(245, 255, 126, 22) else Color.argb(245, 226, 96, 8)
        stroke.strokeWidth = px(1.5f)
        primary.color = if (darkMode) Color.WHITE else Color.rgb(20, 27, 33)
        secondary.color = if (darkMode) Color.rgb(213, 221, 231) else Color.rgb(73, 83, 94)
    }

    private fun drawPreview(canvas: Canvas) {
        val u = scaleUnit()
        val t = textUnit()
        val margin = 18f * u
        val leftW = (width * 0.34f).coerceIn(250f * u, 430f * u)

        // Locked GoVia preview hierarchy: title over map + four compact KPI cards.
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        primary.textSize = 27f * t
        canvas.drawText(ellipsize(previewState.name, 30), margin, margin + 32f * t, primary)

        secondary.typeface = android.graphics.Typeface.DEFAULT
        secondary.textSize = 14f * t
        if (previewState.route.isNotBlank()) {
            canvas.drawText(ellipsize(previewState.route, 43), margin, margin + 58f * t, secondary)
        }

        val gap = 10f * u
        val gridTop = margin + 88f * u
        val cardW = (leftW - gap) / 2f
        val cardH = 76f * u
        drawPreviewMetric(canvas, RectF(margin, gridTop, margin + cardW, gridTop + cardH), previewState.distance, "Distanse", MetricIcon.DISTANCE, u, t)
        drawPreviewMetric(canvas, RectF(margin + cardW + gap, gridTop, margin + leftW, gridTop + cardH), previewState.duration, "Kjøretid", MetricIcon.TIME, u, t)
        val secondTop = gridTop + cardH + gap
        drawPreviewMetric(canvas, RectF(margin, secondTop, margin + cardW, secondTop + cardH), previewState.poiCount, "POI", MetricIcon.POI, u, t)
        drawPreviewMetric(canvas, RectF(margin + cardW + gap, secondTop, margin + leftW, secondTop + cardH), previewState.stopCount, "Stopp", MetricIcon.STOPS, u, t)
    }

    private enum class MetricIcon { DISTANCE, TIME, POI, STOPS }

    private fun drawPreviewMetric(canvas: Canvas, rect: RectF, value: String, label: String, icon: MetricIcon, u: Float, t: Float) {
        roundPanel(canvas, rect, 15f * u, border = true)
        val cx = rect.left + 26f * u
        val cy = rect.centerY()
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = 2.6f * u
        when (icon) {
            MetricIcon.DISTANCE -> {
                canvas.drawCircle(cx, cy - 10f*u, 5f*u, accent)
                canvas.drawCircle(cx, cy + 10f*u, 5f*u, accent)
                canvas.drawLine(cx, cy - 5f*u, cx, cy + 5f*u, accent)
            }
            MetricIcon.TIME -> {
                canvas.drawCircle(cx, cy, 13f*u, accent)
                canvas.drawLine(cx, cy, cx, cy - 8f*u, accent)
                canvas.drawLine(cx, cy, cx + 7f*u, cy + 4f*u, accent)
            }
            MetricIcon.POI -> {
                val path = Path().apply {
                    addCircle(cx, cy - 4f*u, 10f*u, Path.Direction.CW)
                    moveTo(cx - 7f*u, cy + 3f*u)
                    lineTo(cx, cy + 16f*u)
                    lineTo(cx + 7f*u, cy + 3f*u)
                }
                canvas.drawPath(path, accent)
                canvas.drawCircle(cx, cy - 4f*u, 3f*u, accent)
            }
            MetricIcon.STOPS -> {
                canvas.drawCircle(cx - 8f*u, cy, 6f*u, accent)
                canvas.drawCircle(cx + 8f*u, cy, 6f*u, accent)
                canvas.drawLine(cx - 2f*u, cy, cx + 2f*u, cy, accent)
            }
        }
        accent.style = Paint.Style.FILL
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        primary.textSize = 18f * t
        canvas.drawText(ellipsize(value, 10), rect.left + 48f*u, rect.top + 31f*u, primary)
        secondary.typeface = android.graphics.Typeface.DEFAULT
        secondary.textSize = 11.5f * t
        canvas.drawText(label, rect.left + 48f*u, rect.top + 52f*u, secondary)
    }

    private fun drawNavigation(canvas: Canvas) {
        val u = scaleUnit()
        val t = textUnit()
        val margin = 18f * u
        val cardW = (width * 0.35f).coerceIn(330f * u, 470f * u)
        val cardH = (height * 0.36f).coerceIn(190f * u, 226f * u)
        val left = margin
        val top = margin
        val rect = RectF(left, top, left + cardW, top + cardH)
        roundPanel(canvas, rect, 18f * u, border = true)

        val iconBox = RectF(left + 15f*u, top + 16f*u, left + 84f*u, top + 94f*u)
        drawTurnIcon(canvas, iconBox, navigationState.direction, u)

        primary.textSize = 34f * t
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText(navigationState.distance.ifBlank { "—" }, left + 94f*u, top + 45f*u, primary)

        secondary.textSize = 17f * t
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText(ellipsize(navigationState.instruction.ifBlank { "Følg ruten" }, 31), left + 94f*u, top + 74f*u, secondary)

        if (navigationState.road.isNotBlank()) {
            primary.textSize = 20f * t
            primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
            canvas.drawText(ellipsize(navigationState.road, 29), left + 94f*u, top + 104f*u, primary)
        }

        val dividerY = top + cardH - 56f*u
        stroke.color = if (darkMode) Color.argb(115, 210, 220, 230) else Color.argb(86, 35, 45, 55)
        stroke.strokeWidth = 1f*u
        canvas.drawLine(left + 18f*u, dividerY, left + cardW - 18f*u, dividerY, stroke)

        primary.textSize = 15f*t
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        if (navigationState.tripName.isNotBlank()) {
            canvas.drawText(ellipsize(navigationState.tripName, 34), left + 20f*u, dividerY + 22f*u, primary)
        }

        navigationState.poi?.takeIf { it.isNotBlank() }?.let { poi ->
            val poiTop = rect.bottom + 10f*u
            val poiH = 76f*u
            val poiRect = RectF(left, poiTop, left + cardW, poiTop + poiH)
            roundPanel(canvas, poiRect, 16f*u, border = true)
            accent.style = Paint.Style.STROKE
            accent.strokeWidth = 3f*u
            canvas.drawCircle(left + 32f*u, poiTop + poiH/2f, 15f*u, accent)
            accent.style = Paint.Style.FILL
            secondary.textSize = 13f*t
            canvas.drawText("POI nærmer seg", left + 55f*u, poiTop + 24f*u, secondary)
            primary.textSize = 17f*t
            primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
            canvas.drawText(ellipsize(poi, 31), left + 55f*u, poiTop + 47f*u, primary)
        }

        // Dedicated lower status pill, matching the locked navigation hierarchy.
        val statusW = (width * 0.31f).coerceIn(292f * u, 420f * u)
        val statusH = 72f * u
        val statusBottom = height - 18f * u
        val statusTop = statusBottom - statusH
        val statusRect = RectF(left, statusTop, left + statusW, statusBottom)
        roundPanel(canvas, statusRect, 18f * u, border = false)

        primary.textSize = 18f * t
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        val arrival = navigationState.arrival.removePrefix("Ankomst ").ifBlank { "—" }
        canvas.drawText(arrival, left + 20f*u, statusTop + 26f*u, primary)
        secondary.textSize = 12f * t
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText("Ankomst", left + 20f*u, statusTop + 45f*u, secondary)

        val dividerX = left + statusW * 0.46f
        stroke.color = if (darkMode) Color.argb(100, 210, 220, 230) else Color.argb(72, 35, 45, 55)
        stroke.strokeWidth = 1f*u
        canvas.drawLine(dividerX, statusTop + 10f*u, dividerX, statusBottom - 10f*u, stroke)

        primary.textSize = 18f * t
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        val remaining = navigationState.remaining.removeSuffix(" igjen").ifBlank { "—" }
        canvas.drawText(remaining, dividerX + 18f*u, statusTop + 26f*u, primary)
        secondary.textSize = 12f*t
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText("igjen", dividerX + 18f*u, statusTop + 45f*u, secondary)
    }

    private fun drawRecording(canvas: Canvas) {
        val u = scaleUnit()
        val margin = 18f*u
        val cardW = (width * 0.26f).coerceIn(260f*u, 345f*u)
        val cardH = 86f*u
        val rect = RectF(margin, margin, margin + cardW, margin + cardH)
        roundPanel(canvas, rect, 18f*u, border = false)

        red.style = Paint.Style.FILL
        canvas.drawCircle(margin + 31f*u, margin + 29f*u, 8f*u, red)
        primary.textSize = 20f*u
        primary.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText("REC", margin + 50f*u, margin + 35f*u, primary)

        secondary.textSize = 14f*u
        secondary.typeface = android.graphics.Typeface.DEFAULT
        canvas.drawText("${recordingState.elapsed}  ·  ${recordingState.distance}", margin + 50f*u, margin + 63f*u, secondary)

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
            Direction.RIGHT -> { path.moveTo(box.left+18f*u,box.bottom-8f*u); path.lineTo(box.left+18f*u,box.centerY()); path.quadTo(box.left+18f*u,box.top+10f*u,box.left+46f*u,box.top+10f*u); path.lineTo(box.right-10f*u,box.top+10f*u); canvas.drawPath(path,accent); drawArrowHead(canvas,box.right-10f*u,box.top+10f*u,0f,u) }
            Direction.LEFT -> { path.moveTo(box.right-18f*u,box.bottom-8f*u); path.lineTo(box.right-18f*u,box.centerY()); path.quadTo(box.right-18f*u,box.top+10f*u,box.left+20f*u,box.top+10f*u); canvas.drawPath(path,accent); drawArrowHead(canvas,box.left+20f*u,box.top+10f*u,180f,u) }
            Direction.ROUNDABOUT -> { val cx=box.centerX(); val cy=box.centerY(); canvas.drawCircle(cx,cy,22f*u,accent); drawArrowHead(canvas,cx+22f*u,cy,0f,u) }
            Direction.UTURN -> { path.moveTo(box.centerX()+15f*u,box.bottom-8f*u); path.lineTo(box.centerX()+15f*u,box.top+28f*u); path.quadTo(box.centerX()+15f*u,box.top+6f*u,box.centerX()-8f*u,box.top+6f*u); path.quadTo(box.centerX()-30f*u,box.top+6f*u,box.centerX()-30f*u,box.top+28f*u); canvas.drawPath(path,accent); drawArrowHead(canvas,box.centerX()-30f*u,box.top+28f*u,90f,u) }
            Direction.STRAIGHT -> { path.moveTo(box.centerX(),box.bottom-8f*u); path.lineTo(box.centerX(),box.top+13f*u); canvas.drawPath(path,accent); drawArrowHead(canvas,box.centerX(),box.top+13f*u,-90f,u) }
        }
        accent.style = Paint.Style.FILL
    }

    private fun drawArrowHead(canvas: Canvas, x: Float, y: Float, degrees: Float, u: Float) {
        canvas.save(); canvas.rotate(degrees,x,y)
        val p=Path().apply { moveTo(x+13f*u,y); lineTo(x-3f*u,y-10f*u); lineTo(x-3f*u,y+10f*u); close() }
        canvas.drawPath(p,accent); canvas.restore()
    }

    private fun roundPanel(canvas: Canvas, rect: RectF, radius: Float, border: Boolean) {
        canvas.drawRoundRect(rect,radius,radius,panel)
        if (border) { stroke.color=if (darkMode) ORANGE else Color.rgb(220,98,8); stroke.strokeWidth=px(1.4f); canvas.drawRoundRect(rect,radius,radius,stroke) }
    }

    private fun ellipsize(value: String, maxChars: Int): String = if (value.length<=maxChars) value else value.take((maxChars-1).coerceAtLeast(1))+"…"
    private fun scaleUnit(): Float = kotlin.math.min(width / 1280f, height / 600f).coerceIn(0.58f, 1.35f)
    private fun textUnit(): Float = scaleUnit().coerceIn(0.74f, 1.20f)
    private fun px(value: Float): Float = value * scaleUnit()

    companion object {
        private val ORANGE=Color.rgb(255,126,22)
        private val RED=Color.rgb(239,55,55)
        private val GREEN=Color.rgb(52,211,153)
    }
}
