package no.govia.mobile.car

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.view.Surface
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import kotlin.math.max
import kotlin.math.min

class GoViaRouteSurfaceRenderer(private val route: List<CarPoint>) : SurfaceCallback {
    private var surface: Surface? = null
    private var width = 0
    private var height = 0
    private var current: CarPoint? = null
    private var poiAlert: String? = null

    fun updatePosition(point: CarPoint?, poi: String?) {
        current = point
        poiAlert = poi
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
            canvas.drawColor(Color.rgb(7, 20, 31))
            if (route.size > 1) drawRoute(canvas)
            drawPoi(canvas)
        } catch (_: Exception) {
        } finally {
            if (canvas != null) runCatching { target.unlockCanvasAndPost(canvas) }
        }
    }

    private fun drawRoute(canvas: Canvas) {
        val minLon = route.minOf { it.lon }
        val maxLon = route.maxOf { it.lon }
        val minLat = route.minOf { it.lat }
        val maxLat = route.maxOf { it.lat }
        val lonRange = max(maxLon - minLon, 0.0001)
        val latRange = max(maxLat - minLat, 0.0001)
        val padding = min(width, height) * 0.08f
        fun x(point: CarPoint) = padding + (((point.lon - minLon) / lonRange) * (width - padding * 2)).toFloat()
        fun y(point: CarPoint) = height - padding - (((point.lat - minLat) / latRange) * (height - padding * 2)).toFloat()

        val roadPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(45, 66, 79)
            style = Paint.Style.STROKE
            strokeWidth = 18f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val routePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(255, 122, 26)
            style = Paint.Style.STROKE
            strokeWidth = 11f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val path = Path().apply {
            moveTo(x(route.first()), y(route.first()))
            route.drop(1).forEach { lineTo(x(it), y(it)) }
        }
        canvas.drawPath(path, roadPaint)
        canvas.drawPath(path, routePaint)

        current?.let { point ->
            val markerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.FILL }
            val corePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(255, 122, 26); style = Paint.Style.FILL }
            canvas.drawCircle(x(point), y(point), 19f, markerPaint)
            canvas.drawCircle(x(point), y(point), 11f, corePaint)
        }
    }

    private fun drawPoi(canvas: Canvas) {
        val text = poiAlert ?: return
        val margin = min(width, height) * 0.04f
        val top = height - 118f - margin
        val panel = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(35, 29, 22) }
        canvas.drawRoundRect(margin, top, width - margin, height - margin, 22f, 22f, panel)
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(255, 164, 84)
            textSize = 28f
        }
        val valuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 38f
            isFakeBoldText = true
        }
        canvas.drawText("POI nærmer seg", margin + 24f, top + 38f, labelPaint)
        canvas.drawText(text.take(45), margin + 24f, top + 86f, valuePaint)
    }
}
