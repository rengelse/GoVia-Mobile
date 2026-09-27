package no.govia.mobile.car

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.Surface
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class GoViaRouteSurfaceRenderer(private val route: List<CarPoint>) : SurfaceCallback {
    private var surface: Surface? = null
    private var width = 0
    private var height = 0
    private var darkMode = true
    private var uiState = GoViaSurfaceUiState()
    private var recordingPath: List<CarPoint> = emptyList()

    fun setDarkMode(enabled: Boolean) {
        if (darkMode == enabled) return
        darkMode = enabled
        draw()
    }

    fun updateUiState(state: GoViaSurfaceUiState) {
        uiState = state
        draw()
    }

    fun updateRecordingPath(points: List<CarPoint>) {
        recordingPath = points
        draw()
    }

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        surface?.release()
        surface = surfaceContainer.surface
        width = surfaceContainer.width
        height = surfaceContainer.height
        draw()
    }


    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        surface?.release()
        surface = null
    }

    private fun draw() {
        val target = surface ?: return
        if (!target.isValid || width <= 0 || height <= 0) return
        var canvas: Canvas? = null
        try {
            canvas = target.lockCanvas(null)
            drawBackground(canvas)
            drawMap(canvas)
            drawTopCard(canvas)
            if (uiState.poiValue != null) drawPoiBanner(canvas)
            drawBottomStatus(canvas)
            drawControls(canvas)
            if (uiState.recording) drawRecordingFooter(canvas)
        } catch (_: Exception) {
            // Surface can disappear while Android Auto changes screens or display mode.
        } finally {
            if (canvas != null) runCatching { target.unlockCanvasAndPost(canvas) }
        }
    }

    private fun drawBackground(canvas: Canvas) {
        canvas.drawColor(if (darkMode) Color.rgb(7, 20, 31) else Color.rgb(238, 241, 239))
        val contour = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.argb(70, 255, 120, 35) else Color.argb(55, 255, 145, 68)
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        val step = max(80, min(width, height) / 6)
        for (i in -2..4) {
            val path = Path()
            val startY = (i * step).toFloat() + 24f
            path.moveTo(0f, startY)
            path.cubicTo(width * 0.18f, startY + 48f, width * 0.40f, startY - 36f, width * 0.62f, startY + 30f)
            path.cubicTo(width * 0.78f, startY + 68f, width * 0.88f, startY - 24f, width.toFloat(), startY + 24f)
            canvas.drawPath(path, contour)
        }
    }

    private fun drawMap(canvas: Canvas) {
        val source = when {
            recordingPath.size > 1 -> recordingPath
            route.size > 1 -> route
            else -> emptyList()
        }
        if (source.isEmpty()) {
            drawCurrentMarker(canvas, null)
            return
        }
        val bounds = projectedBounds(source, uiState.currentPoint)
        val path = Path()
        source.forEachIndexed { index, point ->
            val p = project(point, bounds)
            if (index == 0) path.moveTo(p.first, p.second) else path.lineTo(p.first, p.second)
        }
        val baseRoad = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.rgb(46, 66, 82) else Color.rgb(188, 196, 194)
            style = Paint.Style.STROKE
            strokeWidth = 20f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val activeRoute = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (uiState.recording) Color.rgb(244, 58, 72) else Color.rgb(255, 128, 24)
            style = Paint.Style.STROKE
            strokeWidth = 12f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(path, baseRoad)
        canvas.drawPath(path, activeRoute)

        if (!uiState.recording) {
            source.firstOrNull()?.let { drawStartPin(canvas, project(it, bounds).first, project(it, bounds).second) }
            source.lastOrNull()?.let { drawFinishPin(canvas, project(it, bounds).first, project(it, bounds).second) }
        }
        drawCurrentMarker(canvas, bounds)
    }

    private fun drawCurrentMarker(canvas: Canvas, bounds: Bounds?) {
        val point = uiState.currentPoint ?: return
        val (x, y) = if (bounds != null) project(point, bounds) else width * 0.55f to height * 0.58f
        val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.argb(72, 255, 255, 255) else Color.argb(55, 23, 31, 36)
            style = Paint.Style.FILL
        }
        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 5f
        }
        val arrow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (uiState.recording) Color.rgb(244, 58, 72) else Color.rgb(255, 128, 24)
            style = Paint.Style.FILL
        }
        canvas.drawCircle(x, y, 42f, halo)
        canvas.drawCircle(x, y, 42f, ring)

        val heading = Math.toRadians(uiState.headingDegrees.toDouble())
        val size = 28f
        val path = Path()
        val frontX = x + kotlin.math.sin(heading).toFloat() * size
        val frontY = y - kotlin.math.cos(heading).toFloat() * size
        val leftX = x + kotlin.math.sin(heading - 2.45).toFloat() * (size * 0.75f)
        val leftY = y - kotlin.math.cos(heading - 2.45).toFloat() * (size * 0.75f)
        val rightX = x + kotlin.math.sin(heading + 2.45).toFloat() * (size * 0.75f)
        val rightY = y - kotlin.math.cos(heading + 2.45).toFloat() * (size * 0.75f)
        path.moveTo(frontX, frontY)
        path.lineTo(leftX, leftY)
        path.lineTo(x, y + size * 0.36f)
        path.lineTo(rightX, rightY)
        path.close()
        canvas.drawPath(path, arrow)
    }

    private fun drawTopCard(canvas: Canvas) {
        val margin = min(width, height) * 0.04f
        val cardWidth = min(width * 0.46f, 560f)
        val cardHeight = if (uiState.subtitle != null) 286f else 220f
        val panel = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = panelColor() }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accentColor()
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        canvas.drawRoundRect(margin, margin, margin + cardWidth, margin + cardHeight, 28f, 28f, panel)
        canvas.drawRoundRect(margin, margin, margin + cardWidth, margin + cardHeight, 28f, 28f, stroke)

        val primary = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.WHITE else Color.rgb(23, 28, 31)
            textSize = 62f
            isFakeBoldText = true
        }
        val secondary = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.rgb(222, 228, 231) else Color.rgb(60, 65, 70)
            textSize = 30f
        }
        val tertiary = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.rgb(192, 200, 204) else Color.rgb(86, 91, 96)
            textSize = 26f
        }
        val accent = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accentColor()
            style = Paint.Style.STROKE
            strokeWidth = 14f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        val titleX = margin + 150f
        canvas.drawText(uiState.title, titleX, margin + 88f, primary)
        uiState.subtitle?.takeIf { it.isNotBlank() }?.let {
            val lines = wrapText(it, secondary, (cardWidth - 190f).toInt(), 2)
            var y = margin + 138f
            lines.forEach { line ->
                canvas.drawText(line, titleX, y, secondary)
                y += 38f
            }
        }

        drawTurnGlyph(canvas, margin + 78f, margin + 90f, accent)
        canvas.drawLine(margin + 28f, margin + cardHeight - 92f, margin + cardWidth - 28f, margin + cardHeight - 92f, tertiary.apply { strokeWidth = 1.5f })

        val routeInfoTitle = Paint(primary).apply { textSize = 24f; isFakeBoldText = true }
        val routeInfo = Paint(secondary).apply { textSize = 22f }
        val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.WHITE else Color.rgb(34, 41, 46)
            style = Paint.Style.STROKE
            strokeWidth = 5f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val baseY = margin + cardHeight - 34f
        drawSimpleRouteIcon(canvas, margin + 52f, baseY - 14f, iconPaint)
        canvas.drawText(uiState.infoTitle ?: "GoVia-tur", margin + 102f, baseY - 16f, routeInfoTitle)
        canvas.drawText(uiState.infoLine ?: "Følg ruten", margin + 102f, baseY + 16f, routeInfo)
    }

    private fun drawPoiBanner(canvas: Canvas) {
        val label = uiState.poiLabel ?: "POI nærmer seg"
        val value = uiState.poiValue ?: return
        val margin = min(width, height) * 0.04f
        val top = margin + 304f
        val bannerWidth = min(width * 0.52f, 680f)
        val panel = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (darkMode) Color.rgb(35, 29, 22) else Color.rgb(255, 246, 237) }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accentColor()
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        canvas.drawRoundRect(margin, top, margin + bannerWidth, top + 104f, 24f, 24f, panel)
        canvas.drawRoundRect(margin, top, margin + bannerWidth, top + 104f, 24f, 24f, stroke)
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.rgb(255, 170, 94) else Color.rgb(179, 74, 0)
            textSize = 24f
        }
        val valuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.WHITE else Color.rgb(29, 31, 34)
            textSize = 30f
            isFakeBoldText = true
        }
        val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accentColor()
            style = Paint.Style.STROKE
            strokeWidth = 5f
        }
        drawPoiIcon(canvas, margin + 56f, top + 54f, iconPaint)
        canvas.drawText(label, margin + 102f, top + 38f, labelPaint)
        canvas.drawText(value.take(38), margin + 102f, top + 78f, valuePaint)
    }

    private fun drawBottomStatus(canvas: Canvas) {
        if (uiState.etaText == null && uiState.remainingText == null) return
        val margin = min(width, height) * 0.04f
        val bottom = height - margin - 30f
        val panel = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = chipColor() }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.argb(80, 255, 255, 255) else Color.argb(55, 31, 38, 42)
            style = Paint.Style.STROKE
            strokeWidth = 1.5f
        }
        val widthPanel = min(width * 0.42f, 520f)
        canvas.drawRoundRect(margin, bottom - 82f, margin + widthPanel, bottom, 26f, 26f, panel)
        canvas.drawRoundRect(margin, bottom - 82f, margin + widthPanel, bottom, 26f, 26f, stroke)

        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.rgb(198, 205, 210) else Color.rgb(81, 86, 91)
            textSize = 21f
        }
        val value = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.WHITE else Color.rgb(26, 31, 35)
            textSize = 28f
            isFakeBoldText = true
        }
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (darkMode) Color.argb(80, 255, 255, 255) else Color.argb(55, 31, 38, 42)
            strokeWidth = 1.5f
        }
        val left = margin + 20f
        val mid = margin + widthPanel / 2f
        uiState.etaText?.let {
            canvas.drawText(it, left + 30f, bottom - 38f, value)
            canvas.drawText("Ankomst", left + 30f, bottom - 12f, label)
        }
        canvas.drawLine(mid, bottom - 68f, mid, bottom - 12f, line)
        uiState.remainingText?.let {
            canvas.drawText(it, mid + 30f, bottom - 38f, value)
            canvas.drawText("igjen", mid + 30f, bottom - 12f, label)
        }
    }

    private fun drawControls(canvas: Canvas) {
        val labels = listOf("lyd", "+", "−", "◎", if (uiState.recording) "■" else "×")
        val colors = listOf(accentColor(), textColor(), textColor(), textColor(), if (uiState.recording) Color.rgb(240, 58, 72) else Color.rgb(233, 69, 81))
        val radius = 42f
        val gap = 24f
        val total = labels.size * radius * 2 + (labels.size - 1) * gap
        var cy = (height - total) / 2f + radius
        val cx = width - min(width, height) * 0.05f - radius
        labels.forEachIndexed { index, label ->
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (darkMode) Color.argb(220, 11, 18, 23) else Color.argb(232, 253, 253, 252) }
            val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (index == labels.lastIndex) colors[index] else Color.argb(95, 255, 255, 255)
                style = Paint.Style.STROKE
                strokeWidth = if (index == labels.lastIndex) 2.6f else 1.8f
            }
            canvas.drawCircle(cx, cy, radius, fill)
            canvas.drawCircle(cx, cy, radius, stroke)
            drawControlGlyph(canvas, cx, cy, label, colors[index])
            cy += radius * 2 + gap
        }
    }

    private fun drawRecordingFooter(canvas: Canvas) {
        val text = uiState.recordingFooter ?: return
        val margin = min(width, height) * 0.04f
        val rect = RectF(width * 0.33f, height - margin - 104f, width * 0.70f, height - margin - 24f)
        val panel = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(220, 156, 15, 24) }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(255, 84, 92)
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        canvas.drawRoundRect(rect, 30f, 30f, panel)
        canvas.drawRoundRect(rect, 30f, 30f, stroke)
        val icon = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.FILL }
        canvas.drawRoundRect(rect.left + 26f, rect.top + 20f, rect.left + 56f, rect.top + 50f, 8f, 8f, icon)
        val value = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 28f
            isFakeBoldText = true
        }
        canvas.drawText(text, rect.left + 88f, rect.centerY() + 10f, value)
    }

    private fun drawTurnGlyph(canvas: Canvas, cx: Float, cy: Float, paint: Paint) {
        val path = Path().apply {
            moveTo(cx - 26f, cy + 52f)
            lineTo(cx - 26f, cy - 4f)
            lineTo(cx + 12f, cy - 4f)
        }
        canvas.drawPath(path, paint)
        val arrow = Path().apply {
            moveTo(cx + 12f, cy - 4f)
            lineTo(cx - 6f, cy - 22f)
            moveTo(cx + 12f, cy - 4f)
            lineTo(cx - 6f, cy + 14f)
        }
        canvas.drawPath(arrow, paint)
    }

    private fun drawSimpleRouteIcon(canvas: Canvas, cx: Float, cy: Float, paint: Paint) {
        val path = Path().apply {
            moveTo(cx - 20f, cy - 14f)
            cubicTo(cx - 38f, cy - 22f, cx - 36f, cy + 10f, cx - 10f, cy + 6f)
            cubicTo(cx + 14f, cy + 2f, cx + 8f, cy - 24f, cx + 24f, cy - 18f)
        }
        canvas.drawPath(path, paint)
    }

    private fun drawPoiIcon(canvas: Canvas, cx: Float, cy: Float, paint: Paint) {
        canvas.drawCircle(cx, cy, 26f, paint)
        canvas.drawLine(cx + 18f, cy, cx + 30f, cy, paint)
        canvas.drawLine(cx + 24f, cy - 8f, cx + 24f, cy + 8f, paint)
    }

    private fun drawStartPin(canvas: Canvas, x: Float, y: Float) {
        val circle = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accentColor(); style = Paint.Style.FILL }
        val inner = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.FILL }
        canvas.drawCircle(x, y, 16f, circle)
        canvas.drawCircle(x, y, 8f, inner)
    }

    private fun drawFinishPin(canvas: Canvas, x: Float, y: Float) {
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.FILL }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (darkMode) Color.rgb(20, 27, 31) else Color.rgb(248, 249, 247); style = Paint.Style.FILL }
        canvas.drawCircle(x, y, 18f, border)
        canvas.drawCircle(x, y, 14f, fill)
        val square = 6f
        for (row in 0..1) {
            for (col in 0..1) {
                val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if ((row + col) % 2 == 0) Color.BLACK else Color.WHITE
                    style = Paint.Style.FILL
                }
                canvas.drawRect(x - 8f + col * square * 2, y - 8f + row * square * 2, x - 8f + col * square * 2 + square, y - 8f + row * square * 2 + square, p)
            }
        }
    }

    private fun drawControlGlyph(canvas: Canvas, cx: Float, cy: Float, label: String, color: Int) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = 5f
            strokeCap = Paint.Cap.ROUND
            textSize = 38f
            textAlign = Paint.Align.CENTER
        }
        when (label) {
            "+", "−" -> canvas.drawText(label, cx, cy + 14f, Paint(paint).apply { style = Paint.Style.FILL; isFakeBoldText = true })
            "◎" -> {
                canvas.drawCircle(cx, cy, 16f, paint)
                canvas.drawLine(cx - 22f, cy, cx - 10f, cy, paint)
                canvas.drawLine(cx + 10f, cy, cx + 22f, cy, paint)
                canvas.drawLine(cx, cy - 22f, cx, cy - 10f, paint)
                canvas.drawLine(cx, cy + 10f, cx, cy + 22f, paint)
            }
            "■" -> {
                canvas.drawRoundRect(cx - 14f, cy - 14f, cx + 14f, cy + 14f, 6f, 6f, Paint(paint).apply { style = Paint.Style.FILL })
            }
            "×" -> {
                canvas.drawLine(cx - 14f, cy - 14f, cx + 14f, cy + 14f, paint)
                canvas.drawLine(cx + 14f, cy - 14f, cx - 14f, cy + 14f, paint)
            }
            "lyd" -> {
                canvas.drawLine(cx - 14f, cy + 8f, cx - 6f, cy + 8f, paint)
                canvas.drawLine(cx - 14f, cy - 8f, cx - 6f, cy - 8f, paint)
                val speaker = Path().apply {
                    moveTo(cx - 6f, cy - 12f)
                    lineTo(cx + 4f, cy - 2f)
                    lineTo(cx + 4f, cy + 2f)
                    lineTo(cx - 6f, cy + 12f)
                    close()
                }
                canvas.drawPath(speaker, Paint(paint).apply { style = Paint.Style.FILL })
                canvas.drawArc(cx + 3f, cy - 18f, cx + 24f, cy + 18f, -45f, 90f, false, paint)
            }
        }
    }

    private fun projectedBounds(points: List<CarPoint>, current: CarPoint?): Bounds {
        val all = if (current != null) points + current else points
        var minLon = all.minOf { it.lon }
        var maxLon = all.maxOf { it.lon }
        var minLat = all.minOf { it.lat }
        var maxLat = all.maxOf { it.lat }
        val lonSpan = max(0.001, abs(maxLon - minLon))
        val latSpan = max(0.001, abs(maxLat - minLat))
        val lonPad = lonSpan * 0.18
        val latPad = latSpan * 0.24
        minLon -= lonPad
        maxLon += lonPad
        minLat -= latPad
        maxLat += latPad
        return Bounds(minLon, maxLon, minLat, maxLat)
    }

    private fun project(point: CarPoint, bounds: Bounds): Pair<Float, Float> {
        val left = width * 0.34f
        val right = width - width * 0.12f
        val top = height * 0.10f
        val bottom = height - height * 0.18f
        val x = left + (((point.lon - bounds.minLon) / max(0.0001, bounds.maxLon - bounds.minLon)) * (right - left)).toFloat()
        val y = bottom - (((point.lat - bounds.minLat) / max(0.0001, bounds.maxLat - bounds.minLat)) * (bottom - top)).toFloat()
        return x to y
    }

    private fun wrapText(text: String, paint: Paint, maxWidth: Int, maxLines: Int): List<String> {
        val words = text.split(' ')
        val lines = mutableListOf<String>()
        var current = ""
        for (word in words) {
            val next = if (current.isBlank()) word else "$current $word"
            if (paint.measureText(next) <= maxWidth || current.isBlank()) {
                current = next
            } else {
                lines += current
                current = word
                if (lines.size == maxLines - 1) break
            }
        }
        if (current.isNotBlank() && lines.size < maxLines) lines += current
        return lines
    }

    private fun accentColor(): Int = if (uiState.recording) Color.rgb(244, 58, 72) else Color.rgb(255, 128, 24)
    private fun panelColor(): Int = if (darkMode) Color.argb(224, 10, 16, 22) else Color.argb(232, 252, 252, 250)
    private fun chipColor(): Int = if (darkMode) Color.argb(216, 12, 19, 24) else Color.argb(230, 250, 250, 249)
    private fun textColor(): Int = if (darkMode) Color.WHITE else Color.rgb(31, 38, 42)

    data class GoViaSurfaceUiState(
        val title: String = "Følg ruten",
        val subtitle: String? = null,
        val infoTitle: String? = null,
        val infoLine: String? = null,
        val currentPoint: CarPoint? = null,
        val headingDegrees: Float = 0f,
        val poiLabel: String? = null,
        val poiValue: String? = null,
        val etaText: String? = null,
        val remainingText: String? = null,
        val recording: Boolean = false,
        val recordingFooter: String? = null,
    )

    private data class Bounds(val minLon: Double, val maxLon: Double, val minLat: Double, val maxLat: Double)
}
