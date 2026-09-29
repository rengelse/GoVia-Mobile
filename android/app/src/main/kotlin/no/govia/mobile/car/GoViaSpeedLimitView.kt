package no.govia.mobile.car

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.view.View
import kotlin.math.min

/**
 * Non-interactive road speed-limit sign rendered inside the Android Auto map safe area.
 * A value is shown only when Navigation Core has a reliable limit for the active route section.
 */
class GoViaSpeedLimitView(context: Context) : View(context) {

    var speedLimitKph: Int? = null
        set(value) {
            val normalized = value?.takeIf { it in 1..200 }
            if (field == normalized) return
            field = normalized
            visibility = if (normalized == null) GONE else VISIBLE
            contentDescription = normalized?.let { "Fartsgrense $it" }
            invalidate()
        }

    private val whitePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private val redPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(218, 35, 35)
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLACK
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    init {
        isClickable = false
        isFocusable = false
        visibility = GONE
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val value = speedLimitKph ?: return
        val diameter = min(width, height).toFloat()
        if (diameter <= 0f) return
        val cx = width / 2f
        val cy = height / 2f
        val outerRadius = diameter * 0.46f
        redPaint.strokeWidth = diameter * 0.085f
        canvas.drawCircle(cx, cy, outerRadius, whitePaint)
        canvas.drawCircle(cx, cy, outerRadius - redPaint.strokeWidth / 2f, redPaint)

        val digits = value.toString().length
        textPaint.textSize = diameter * if (digits >= 3) 0.39f else 0.46f
        val metrics = textPaint.fontMetrics
        val baseline = cy - (metrics.ascent + metrics.descent) / 2f
        canvas.drawText(value.toString(), cx, baseline, textPaint)
    }
}
