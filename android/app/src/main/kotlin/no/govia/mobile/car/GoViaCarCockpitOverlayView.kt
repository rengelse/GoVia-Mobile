package no.govia.mobile.car

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.view.View
import no.govia.mobile.R
import kotlin.math.min

/**
 * GoVia-owned visual cockpit drawn on top of the Android Auto map surface.
 *
 * The geometry intentionally follows the locked 800x400 / wide-screen reference:
 * branded header, compact left guidance stack, map-first centre, persistent right
 * controls and a separate lower trip-status pill.
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
        val voiceMuted: Boolean = false,
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

    data class HomeState(
        val activeTripName: String? = null,
        val recordingActive: Boolean = false,
    )

    data class TripCard(
        val title: String,
        val meta: String,
    )

    data class TripsState(
        val activeTab: String = "planned",
        val trips: List<TripCard> = emptyList(),
    )

    enum class Mode { HOME, TRIPS, PREVIEW, NAVIGATION, RECORDING }
    enum class Direction { LEFT, RIGHT, STRAIGHT, ROUNDABOUT, UTURN }
    enum class Control {
        SOUND, ZOOM_IN, ZOOM_OUT, RECENTER, STOP,
        HOME_CONTINUE, HOME_TRIPS, HOME_RECORD, BACK,
        TAB_PLANNED, TAB_ACTIVE, TAB_COMPLETED, TAB_RECORD,
        TRIP_0, TRIP_1, TRIP_2, TRIP_3,
    }

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
    var homeState: HomeState = HomeState()
        set(value) { field = value; invalidate() }
    var tripsState: TripsState = TripsState()
        set(value) { field = value; invalidate() }

    private val panel = Paint(Paint.ANTI_ALIAS_FLAG)
    private val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val primary = Paint(Paint.ANTI_ALIAS_FLAG)
    private val secondary = Paint(Paint.ANTI_ALIAS_FLAG)
    private val accent = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ORANGE }
    private val red = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = RED }
    private val green = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = GREEN }
    private val controlHits = linkedMapOf<Control, RectF>()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) return
        configurePalette()
        controlHits.clear()
        when (mode) {
            Mode.HOME -> drawHome(canvas)
            Mode.TRIPS -> drawTrips(canvas)
            Mode.PREVIEW -> drawPreview(canvas)
            Mode.NAVIGATION -> drawNavigation(canvas)
            Mode.RECORDING -> drawRecording(canvas)
        }
    }

    fun controlAt(x: Float, y: Float): Control? =
        controlHits.entries.firstOrNull { it.value.contains(x, y) }?.key

    private fun configurePalette() {
        panel.color = if (darkMode) Color.argb(242, 7, 12, 18) else Color.argb(246, 250, 250, 248)
        headerPaint.color = if (darkMode) Color.argb(236, 3, 8, 13) else Color.argb(244, 248, 248, 246)
        stroke.color = if (darkMode) Color.argb(245, 255, 126, 22) else Color.argb(245, 226, 96, 8)
        stroke.strokeWidth = 1.4f * unit()
        primary.color = if (darkMode) Color.WHITE else Color.rgb(20, 27, 33)
        secondary.color = if (darkMode) Color.rgb(211, 218, 228) else Color.rgb(73, 83, 94)
    }

    private fun drawHeader(canvas: Canvas, u: Float, t: Float) {
        val h = 70f * u
        canvas.drawRect(0f, 0f, width.toFloat(), h, headerPaint)

        // Compact GoVia route mark; this is UI chrome only and does not replace app branding assets.
        accent.style = Paint.Style.FILL
        val markX = 26f * u
        val markY = 16f * u
        val mark = Path().apply {
            moveTo(markX, markY + 36f * u)
            lineTo(markX + 18f * u, markY)
            lineTo(markX + 39f * u, markY + 36f * u)
            lineTo(markX + 29f * u, markY + 33f * u)
            lineTo(markX + 18f * u, markY + 17f * u)
            lineTo(markX + 9f * u, markY + 33f * u)
            close()
        }
        canvas.drawPath(mark, accent)

        primary.typeface = Typeface.DEFAULT_BOLD
        primary.textSize = 30f * t
        canvas.drawText("GoVia", 76f * u, 46f * u, primary)

        stroke.color = if (darkMode) Color.argb(150, 220, 226, 234) else Color.argb(100, 45, 54, 64)
        stroke.strokeWidth = 1f * u
        canvas.drawLine(166f * u, 18f * u, 166f * u, 52f * u, stroke)

        secondary.typeface = Typeface.DEFAULT
        secondary.textSize = 11.5f * t
        canvas.drawText("RIDE FURTHER", 188f * u, 42f * u, secondary)
    }

    private fun drawHome(canvas: Canvas) {
        val u = unit()
        val t = textUnit()
        drawOpaqueBackground(canvas, u)
        drawBrandHeader(canvas, u, t, null, back = false)

        val left = 34f * u
        val right = width - 34f * u
        val top = 92f * u
        val gap = 18f * u
        val activeH = if (homeState.activeTripName.isNullOrBlank()) 0f else 50f * u
        val available = height - top - 28f * u - activeH - if (activeH > 0f) gap else 0f
        val cardH = ((available - gap) / 2f).coerceAtMost(132f * u)

        val tripsRect = RectF(left, top, right, top + cardH)
        val recordRect = RectF(left, tripsRect.bottom + gap, right, tripsRect.bottom + gap + cardH)
        drawHomeCard(canvas, tripsRect, "Turer", "Velg en planlagt eller aktiv GoVia-tur", true, u, t)
        drawHomeCard(canvas, recordRect, if (homeState.recordingActive) "Opptak pågår" else "Ta opp", if (homeState.recordingActive) "Fortsett registreringen" else "Registrer turen du faktisk kjører", false, u, t)
        controlHits[Control.HOME_TRIPS] = RectF(tripsRect)
        controlHits[Control.HOME_RECORD] = RectF(recordRect)

        homeState.activeTripName?.takeIf { it.isNotBlank() }?.let { name ->
            val activeRect = RectF(left, recordRect.bottom + gap, right, recordRect.bottom + gap + activeH)
            roundPanel(canvas, activeRect, 14f * u, border = true, warm = true)
            accent.style = Paint.Style.FILL
            canvas.drawCircle(activeRect.left + 26f*u, activeRect.centerY(), 7f*u, accent)
            primary.typeface = Typeface.DEFAULT_BOLD
            primary.textSize = 14.5f * t
            canvas.drawText("Fortsett tur", activeRect.left + 46f*u, activeRect.centerY() - 2f*u, primary)
            secondary.typeface = Typeface.DEFAULT
            secondary.textSize = 11.5f * t
            canvas.drawText(ellipsize(name, 42), activeRect.left + 150f*u, activeRect.centerY() - 2f*u, secondary)
            drawChevron(canvas, activeRect.right - 26f*u, activeRect.centerY(), u)
            controlHits[Control.HOME_CONTINUE] = RectF(activeRect)
        }
    }

    private fun drawHomeCard(canvas: Canvas, rect: RectF, title: String, subtitle: String, routeIcon: Boolean, u: Float, t: Float) {
        roundPanel(canvas, rect, 16f*u, border = true)
        val iconSize = (rect.height() - 26f*u).coerceAtMost(92f*u)
        val iconRect = RectF(rect.left + 18f*u, rect.centerY() - iconSize/2f, rect.left + 18f*u + iconSize, rect.centerY() + iconSize/2f)
        panel.color = if (darkMode) Color.argb(238, 22, 17, 14) else Color.argb(246, 250, 244, 238)
        canvas.drawRoundRect(iconRect, 14f*u, 14f*u, panel)
        stroke.color = ORANGE
        stroke.strokeWidth = 1.4f*u
        canvas.drawRoundRect(iconRect, 14f*u, 14f*u, stroke)
        if (routeIcon) drawRouteCardIcon(canvas, iconRect, u) else drawRecordIcon(canvas, iconRect, u)

        val textX = iconRect.right + 30f*u
        primary.typeface = Typeface.DEFAULT_BOLD
        primary.textSize = 28f*t
        canvas.drawText(title, textX, rect.centerY() - 3f*u, primary)
        secondary.typeface = Typeface.DEFAULT
        secondary.textSize = 16f*t
        canvas.drawText(ellipsize(subtitle, 48), textX, rect.centerY() + 34f*u, secondary)
        drawChevron(canvas, rect.right - 36f*u, rect.centerY(), u)
    }

    private fun drawTrips(canvas: Canvas) {
        val u = unit()
        val t = textUnit()
        drawOpaqueBackground(canvas, u)
        drawBrandHeader(canvas, u, t, "Turer", back = true)

        val margin = 26f*u
        val tabTop = 78f*u
        val tabGap = 8f*u
        val tabH = 54f*u
        val tabW = (width - margin*2f - tabGap*3f) / 4f
        val tabs = listOf(
            Triple("planned", "Planlagt", Control.TAB_PLANNED),
            Triple("active", "Aktiv", Control.TAB_ACTIVE),
            Triple("completed", "Fullført", Control.TAB_COMPLETED),
            Triple("record", "Ta opp", Control.TAB_RECORD),
        )
        tabs.forEachIndexed { index, (id, label, control) ->
            val l = margin + index * (tabW + tabGap)
            val rect = RectF(l, tabTop, l + tabW, tabTop + tabH)
            val selected = tripsState.activeTab == id
            panel.color = if (selected && darkMode) Color.argb(245, 31, 18, 11) else if (darkMode) Color.argb(242, 7, 12, 18) else Color.argb(246, 250, 250, 248)
            canvas.drawRoundRect(rect, 15f*u, 15f*u, panel)
            stroke.color = if (selected) ORANGE else if (darkMode) Color.rgb(68, 76, 84) else Color.rgb(180, 184, 188)
            stroke.strokeWidth = if (selected) 1.8f*u else 1f*u
            canvas.drawRoundRect(rect, 15f*u, 15f*u, stroke)
            if (selected) drawTabIcon(canvas, rect.left + 28f*u, rect.centerY(), index, u, accent) else drawTabIcon(canvas, rect.left + 28f*u, rect.centerY(), index, u, secondary)
            val paint = if (selected) primary else secondary
            paint.typeface = if (selected) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textSize = 16.5f*t
            canvas.drawText(label, rect.left + 54f*u, rect.centerY() + 6f*u, paint)
            controlHits[control] = RectF(rect)
        }

        val listTop = tabTop + tabH + 12f*u
        val rowGap = 8f*u
        val rowH = ((height - listTop - 18f*u - rowGap*3f) / 4f).coerceAtMost(78f*u)
        if (tripsState.trips.isEmpty()) {
            secondary.typeface = Typeface.DEFAULT
            secondary.textSize = 17f*t
            val empty = when (tripsState.activeTab) {
                "active" -> "Ingen aktive turer"
                "completed" -> "Ingen fullførte turer"
                else -> "Ingen planlagte turer"
            }
            canvas.drawText(empty, margin + 10f*u, listTop + 42f*u, secondary)
        } else {
            tripsState.trips.take(4).forEachIndexed { index, trip ->
                val top = listTop + index*(rowH + rowGap)
                val rect = RectF(margin, top, width - margin, top + rowH)
                roundPanel(canvas, rect, 14f*u, border = true)
                val iconRect = RectF(rect.left + 18f*u, rect.top + 8f*u, rect.left + 88f*u, rect.bottom - 8f*u)
                panel.color = if (darkMode) Color.argb(240, 24, 17, 13) else Color.argb(246, 250, 244, 238)
                canvas.drawRoundRect(iconRect, 13f*u, 13f*u, panel)
                stroke.color = ORANGE
                stroke.strokeWidth = 1.3f*u
                canvas.drawRoundRect(iconRect, 13f*u, 13f*u, stroke)
                drawRouteCardIcon(canvas, iconRect, u)

                primary.typeface = Typeface.DEFAULT_BOLD
                primary.textSize = 17.5f*t
                canvas.drawText(ellipsize(trip.title, 34), rect.left + 110f*u, rect.top + 31f*u, primary)
                secondary.typeface = Typeface.DEFAULT
                secondary.textSize = 13.5f*t
                canvas.drawText(ellipsize(trip.meta, 48), rect.left + 110f*u, rect.top + 57f*u, secondary)
                drawChevron(canvas, rect.right - 28f*u, rect.centerY(), u)
                controlHits[listOf(Control.TRIP_0, Control.TRIP_1, Control.TRIP_2, Control.TRIP_3)[index]] = RectF(rect)
            }
        }
    }

    private fun drawOpaqueBackground(canvas: Canvas, u: Float) {
        canvas.drawColor(if (darkMode) Color.rgb(5, 9, 13) else Color.rgb(244, 245, 242))
        stroke.style = Paint.Style.STROKE
        stroke.strokeWidth = 1f*u
        stroke.color = if (darkMode) Color.argb(54, 255, 126, 22) else Color.argb(38, 226, 96, 8)
        repeat(6) { i ->
            val y = (58f + i*58f)*u
            val p = Path().apply {
                moveTo(width*0.52f, y)
                cubicTo(width*0.66f, y - 42f*u, width*0.79f, y + 36f*u, width.toFloat(), y - 18f*u)
            }
            canvas.drawPath(p, stroke)
        }
    }

    private fun drawBrandHeader(canvas: Canvas, u: Float, t: Float, title: String?, back: Boolean) {
        val h = 70f*u
        canvas.drawRect(0f, 0f, width.toFloat(), h, headerPaint)
        var logoX = 28f*u
        if (back) {
            val hit = RectF(12f*u, 10f*u, 66f*u, 60f*u)
            controlHits[Control.BACK] = RectF(hit)
            primary.style = Paint.Style.STROKE
            primary.strokeWidth = 3.2f*u
            primary.strokeCap = Paint.Cap.ROUND
            canvas.drawLine(46f*u, 23f*u, 30f*u, 35f*u, primary)
            canvas.drawLine(30f*u, 35f*u, 46f*u, 47f*u, primary)
            primary.style = Paint.Style.FILL
            logoX = 74f*u
        }
        val logo = BitmapFactory.decodeResource(resources, R.drawable.govia_logo_horizontal)
        if (logo != null) {
            val ratio = logo.width.toFloat() / logo.height.toFloat()
            val targetH = 42f*u
            val targetW = targetH*ratio
            canvas.drawBitmap(logo, null, RectF(logoX, 13f*u, logoX + targetW, 13f*u + targetH), null)
            val dividerX = logoX + targetW + 18f*u
            stroke.color = if (darkMode) Color.argb(140, 220,226,234) else Color.argb(90,45,54,64)
            stroke.strokeWidth = 1f*u
            canvas.drawLine(dividerX, 16f*u, dividerX, 54f*u, stroke)
            if (title != null) {
                primary.typeface = Typeface.DEFAULT
                primary.textSize = 18f*t
                canvas.drawText(title, dividerX + 20f*u, 44f*u, primary)
            } else {
                secondary.typeface = Typeface.DEFAULT
                secondary.textSize = 11f*t
                canvas.drawText("RIDE FURTHER", dividerX + 20f*u, 42f*u, secondary)
            }
        }
    }

    private fun drawRouteCardIcon(canvas: Canvas, rect: RectF, u: Float) {
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = 3.2f*u
        accent.strokeCap = Paint.Cap.ROUND
        val y = rect.centerY()+8f*u
        val p = Path().apply {
            moveTo(rect.left+16f*u, y)
            cubicTo(rect.left+28f*u, y, rect.left+27f*u, y-15f*u, rect.left+42f*u, y-15f*u)
            cubicTo(rect.left+50f*u, y-15f*u, rect.left+52f*u, y-2f*u, rect.right-17f*u, y-2f*u)
        }
        canvas.drawPath(p, accent)
        drawPin(canvas, rect.right-20f*u, rect.top+20f*u, u*0.7f, accent)
        accent.style = Paint.Style.FILL
    }

    private fun drawRecordIcon(canvas: Canvas, rect: RectF, u: Float) {
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = 4f*u
        canvas.drawCircle(rect.centerX(), rect.centerY(), 24f*u, accent)
        canvas.drawCircle(rect.centerX(), rect.centerY(), 12f*u, accent)
        accent.style = Paint.Style.FILL
    }

    private fun drawTabIcon(canvas: Canvas, cx: Float, cy: Float, index: Int, u: Float, paint: Paint) {
        val old = paint.style
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2.6f*u
        paint.strokeCap = Paint.Cap.ROUND
        if (index == 0) {
            repeat(3) { i ->
                val yy = cy + (i-1)*8f*u
                canvas.drawCircle(cx-8f*u, yy, 1.4f*u, paint)
                canvas.drawLine(cx-2f*u, yy, cx+14f*u, yy, paint)
            }
        } else {
            canvas.drawCircle(cx, cy, 12f*u, paint)
            if (index == 2) {
                canvas.drawLine(cx-5f*u, cy, cx-1f*u, cy+5f*u, paint)
                canvas.drawLine(cx-1f*u, cy+5f*u, cx+7f*u, cy-6f*u, paint)
            } else {
                canvas.drawCircle(cx, cy, 4f*u, paint)
            }
        }
        paint.style = old
    }

    private fun drawPreview(canvas: Canvas) {
        val u = unit()
        val t = textUnit()
        drawHeader(canvas, u, t)

        val margin = 24f * u
        val headerH = 70f * u
        val contentTop = headerH + 16f * u
        val left = margin
        val right = width - margin

        primary.typeface = Typeface.DEFAULT_BOLD
        primary.textSize = 28f * t
        canvas.drawText(ellipsize(previewState.name, 32), left, contentTop + 31f * u, primary)

        secondary.typeface = Typeface.DEFAULT
        secondary.textSize = 15f * t
        if (previewState.route.isNotBlank()) {
            canvas.drawText(ellipsize(previewState.route, 54), left, contentTop + 57f * u, secondary)
        }

        // KPI row sits low and compact so the map remains the dominant visual surface.
        val gap = 10f * u
        val rowTop = height - 100f * u
        val cardW = (right - left - gap * 3f) / 4f
        val cardH = 70f * u
        drawPreviewMetric(canvas, RectF(left, rowTop, left + cardW, rowTop + cardH), previewState.distance, "Distanse", MetricIcon.DISTANCE, u, t)
        drawPreviewMetric(canvas, RectF(left + (cardW + gap), rowTop, left + (cardW + gap) + cardW, rowTop + cardH), previewState.duration, "Estimert tid", MetricIcon.TIME, u, t)
        drawPreviewMetric(canvas, RectF(left + 2f * (cardW + gap), rowTop, left + 2f * (cardW + gap) + cardW, rowTop + cardH), previewState.poiCount, "POI", MetricIcon.POI, u, t)
        drawPreviewMetric(canvas, RectF(left + 3f * (cardW + gap), rowTop, right, rowTop + cardH), previewState.stopCount, "Stopp", MetricIcon.STOPS, u, t)
    }

    private enum class MetricIcon { DISTANCE, TIME, POI, STOPS }

    private fun drawPreviewMetric(canvas: Canvas, rect: RectF, value: String, label: String, icon: MetricIcon, u: Float, t: Float) {
        roundPanel(canvas, rect, 13f * u, border = true)
        val cx = rect.left + 24f * u
        val cy = rect.centerY()
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = 2.5f * u
        accent.strokeCap = Paint.Cap.ROUND
        when (icon) {
            MetricIcon.DISTANCE -> {
                val p = Path().apply {
                    moveTo(cx - 9f*u, cy + 8f*u); cubicTo(cx - 9f*u, cy - 10f*u, cx + 8f*u, cy + 10f*u, cx + 9f*u, cy - 8f*u)
                }
                canvas.drawPath(p, accent)
            }
            MetricIcon.TIME -> {
                canvas.drawCircle(cx, cy, 12f*u, accent)
                canvas.drawLine(cx, cy, cx, cy - 7f*u, accent)
                canvas.drawLine(cx, cy, cx + 6f*u, cy + 4f*u, accent)
            }
            MetricIcon.POI -> drawPin(canvas, cx, cy, u, accent)
            MetricIcon.STOPS -> {
                canvas.drawCircle(cx - 7f*u, cy, 5.5f*u, accent)
                canvas.drawCircle(cx + 7f*u, cy, 5.5f*u, accent)
                canvas.drawLine(cx - 1.5f*u, cy, cx + 1.5f*u, cy, accent)
            }
        }
        accent.style = Paint.Style.FILL
        primary.typeface = Typeface.DEFAULT_BOLD
        primary.textSize = 16.5f * t
        canvas.drawText(ellipsize(value, 11), rect.left + 46f*u, rect.top + 29f*u, primary)
        secondary.typeface = Typeface.DEFAULT
        secondary.textSize = 11f * t
        canvas.drawText(label, rect.left + 46f*u, rect.top + 50f*u, secondary)
    }

    private fun drawNavigation(canvas: Canvas) {
        val u = unit()
        val t = textUnit()
        drawHeader(canvas, u, t)

        val margin = 26f * u
        val headerH = 70f * u
        val left = margin
        val top = headerH + 18f * u
        val cardW = min(width * 0.39f, 520f * u)
        val cardH = if (navigationState.road.isNotBlank()) 148f * u else 126f * u
        val rect = RectF(left, top, left + cardW, top + cardH)
        roundPanel(canvas, rect, 16f * u, border = true)

        val iconBox = RectF(left + 18f*u, top + 18f*u, left + 96f*u, top + 112f*u)
        drawTurnIcon(canvas, iconBox, navigationState.direction, u)

        val textX = left + 112f * u
        primary.textSize = 35f * t
        primary.typeface = Typeface.DEFAULT_BOLD
        canvas.drawText(navigationState.distance.ifBlank { "—" }, textX, top + 51f*u, primary)

        secondary.textSize = 17f * t
        secondary.typeface = Typeface.DEFAULT
        canvas.drawText(ellipsize(navigationState.instruction.ifBlank { "Følg ruten" }, 28), textX, top + 84f*u, secondary)

        if (navigationState.road.isNotBlank()) {
            primary.textSize = 20f * t
            primary.typeface = Typeface.DEFAULT_BOLD
            canvas.drawText(ellipsize(navigationState.road, 26), textX, top + 115f*u, primary)
        }

        // POI card: locked directly below guidance card, same left edge and visual width.
        navigationState.poi?.takeIf { it.isNotBlank() }?.let { poi ->
            val poiTop = rect.bottom + 12f*u
            val poiH = 78f*u
            val poiRect = RectF(left, poiTop, left + cardW, poiTop + poiH)
            roundPanel(canvas, poiRect, 16f*u, border = true, warm = true)
            drawCoffeeIcon(canvas, left + 38f*u, poiTop + poiH/2f, u)
            secondary.textSize = 13f*t
            secondary.typeface = Typeface.DEFAULT
            canvas.drawText("POI nærmer seg", left + 72f*u, poiTop + 29f*u, secondary)
            primary.textSize = 17.5f*t
            primary.typeface = Typeface.DEFAULT_BOLD
            canvas.drawText(ellipsize(poi, 32), left + 72f*u, poiTop + 55f*u, primary)
            drawChevron(canvas, poiRect.right - 28f*u, poiRect.centerY(), u)
        }

        // Bottom status pill, anchored independently from the guidance/POI stack.
        val statusW = min(width * 0.36f, 440f * u)
        val statusH = 68f * u
        val statusBottom = height - 18f*u
        val statusTop = statusBottom - statusH
        val statusRect = RectF(left, statusTop, left + statusW, statusBottom)
        roundPanel(canvas, statusRect, 18f*u, border = false)

        drawFlag(canvas, left + 27f*u, statusTop + 30f*u, u)
        val arrival = navigationState.arrival.removePrefix("Ankomst ").ifBlank { "—" }
        primary.textSize = 18f*t
        primary.typeface = Typeface.DEFAULT_BOLD
        canvas.drawText(arrival, left + 58f*u, statusTop + 28f*u, primary)
        secondary.textSize = 11.5f*t
        secondary.typeface = Typeface.DEFAULT
        canvas.drawText("Ankomst", left + 58f*u, statusTop + 49f*u, secondary)

        val dividerX = left + statusW * 0.50f
        stroke.color = if (darkMode) Color.argb(100, 210, 220, 230) else Color.argb(72, 35, 45, 55)
        stroke.strokeWidth = 1f*u
        canvas.drawLine(dividerX, statusTop + 12f*u, dividerX, statusBottom - 12f*u, stroke)
        drawRoadIcon(canvas, dividerX + 26f*u, statusTop + 31f*u, u)
        val remaining = navigationState.remaining.removeSuffix(" igjen").ifBlank { "—" }
        primary.textSize = 18f*t
        primary.typeface = Typeface.DEFAULT_BOLD
        canvas.drawText(remaining, dividerX + 54f*u, statusTop + 28f*u, primary)
        secondary.textSize = 11.5f*t
        secondary.typeface = Typeface.DEFAULT
        canvas.drawText("igjen", dividerX + 54f*u, statusTop + 49f*u, secondary)

        drawNavigationControls(canvas, u)
    }

    private fun drawNavigationControls(canvas: Canvas, u: Float) {
        val size = 64f * u
        val gap = 18f * u
        val right = width - 22f * u
        val startY = 88f * u
        val regularControls = listOf(Control.SOUND, Control.ZOOM_IN, Control.ZOOM_OUT, Control.RECENTER)

        regularControls.forEachIndexed { index, control ->
            val top = startY + index * (size + gap)
            val rect = RectF(right - size, top, right, top + size)
            drawNavigationControl(canvas, rect, control, u)
        }

        // Keep stop visually and physically separated from the navigation tools so it is
        // difficult to hit by mistake. The tap itself opens a confirmation screen.
        val stopBottom = height - 24f * u
        val stopRect = RectF(right - size, stopBottom - size, right, stopBottom)
        drawNavigationControl(canvas, stopRect, Control.STOP, u)
    }

    private fun drawNavigationControl(canvas: Canvas, rect: RectF, control: Control, u: Float) {
        controlHits[control] = RectF(rect)
        if (control == Control.STOP) {
            canvas.drawOval(rect, red)
        } else {
            panel.color = if (darkMode) Color.argb(245, 4, 10, 16) else Color.argb(247, 250, 250, 248)
            canvas.drawOval(rect, panel)
            stroke.color = if (darkMode) Color.rgb(86, 111, 134) else Color.rgb(116, 128, 140)
            stroke.strokeWidth = 1.2f*u
            canvas.drawOval(rect, stroke)
        }
        drawControlIcon(canvas, rect, control, u)
    }

    private fun drawControlIcon(canvas: Canvas, rect: RectF, control: Control, u: Float) {
        val cx = rect.centerX()
        val cy = rect.centerY()
        val p = if (control == Control.SOUND && !navigationState.voiceMuted) accent else primary
        p.style = Paint.Style.STROKE
        p.strokeWidth = 4f*u
        p.strokeCap = Paint.Cap.ROUND
        p.strokeJoin = Paint.Join.ROUND
        when (control) {
            Control.SOUND -> {
                val path = Path().apply {
                    moveTo(cx - 17f*u, cy - 6f*u); lineTo(cx - 9f*u, cy - 6f*u)
                    lineTo(cx + 1f*u, cy - 15f*u); lineTo(cx + 1f*u, cy + 15f*u)
                    lineTo(cx - 9f*u, cy + 6f*u); lineTo(cx - 17f*u, cy + 6f*u); close()
                }
                canvas.drawPath(path, p)
                if (navigationState.voiceMuted) {
                    canvas.drawLine(cx + 8f*u, cy - 9f*u, cx + 19f*u, cy + 9f*u, p)
                    canvas.drawLine(cx + 19f*u, cy - 9f*u, cx + 8f*u, cy + 9f*u, p)
                } else {
                    canvas.drawArc(RectF(cx + 3f*u, cy - 12f*u, cx + 23f*u, cy + 12f*u), -55f, 110f, false, p)
                }
            }
            Control.ZOOM_IN -> {
                canvas.drawLine(cx - 14f*u, cy, cx + 14f*u, cy, p)
                canvas.drawLine(cx, cy - 14f*u, cx, cy + 14f*u, p)
            }
            Control.ZOOM_OUT -> canvas.drawLine(cx - 14f*u, cy, cx + 14f*u, cy, p)
            Control.RECENTER -> {
                canvas.drawCircle(cx, cy, 11f*u, p)
                canvas.drawCircle(cx, cy, 4f*u, p)
                canvas.drawLine(cx, cy - 20f*u, cx, cy - 13f*u, p)
                canvas.drawLine(cx, cy + 13f*u, cx, cy + 20f*u, p)
                canvas.drawLine(cx - 20f*u, cy, cx - 13f*u, cy, p)
                canvas.drawLine(cx + 13f*u, cy, cx + 20f*u, cy, p)
            }
            Control.STOP -> {
                canvas.drawLine(cx - 13f*u, cy - 13f*u, cx + 13f*u, cy + 13f*u, p)
                canvas.drawLine(cx + 13f*u, cy - 13f*u, cx - 13f*u, cy + 13f*u, p)
            }
            else -> Unit
        }
        p.style = Paint.Style.FILL
    }

    private fun drawRecording(canvas: Canvas) {
        val u = unit()
        val t = textUnit()
        drawHeader(canvas, u, t)
        val margin = 24f*u
        val top = 88f*u
        val cardW = min(width * 0.30f, 360f*u)
        val cardH = 88f*u
        val rect = RectF(margin, top, margin + cardW, top + cardH)
        roundPanel(canvas, rect, 16f*u, border = true)

        red.style = Paint.Style.FILL
        canvas.drawCircle(margin + 30f*u, top + 29f*u, 8f*u, red)
        primary.textSize = 20f*t
        primary.typeface = Typeface.DEFAULT_BOLD
        canvas.drawText("REC", margin + 50f*u, top + 35f*u, primary)
        secondary.textSize = 14f*t
        secondary.typeface = Typeface.DEFAULT
        canvas.drawText("${recordingState.elapsed}  ·  ${recordingState.distance}", margin + 50f*u, top + 63f*u, secondary)

        val gpsLabel = if (recordingState.gpsActive) "GPS aktiv" else "Venter på GPS"
        val gpsW = 132f*u
        val gpsRect = RectF(margin, height - 58f*u, margin + gpsW, height - 18f*u)
        roundPanel(canvas, gpsRect, 13f*u, border = false)
        canvas.drawCircle(margin + 18f*u, height - 38f*u, 6f*u, if (recordingState.gpsActive) green else secondary)
        primary.textSize = 14f*t
        primary.typeface = Typeface.DEFAULT_BOLD
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
                path.moveTo(box.left+18f*u, box.bottom-8f*u)
                path.lineTo(box.left+18f*u, box.centerY())
                path.quadTo(box.left+18f*u, box.top+10f*u, box.left+48f*u, box.top+10f*u)
                path.lineTo(box.right-12f*u, box.top+10f*u)
                canvas.drawPath(path,accent)
                drawArrowHead(canvas, box.right-12f*u, box.top+10f*u, 0f, u)
            }
            Direction.LEFT -> {
                path.moveTo(box.right-18f*u,box.bottom-8f*u)
                path.lineTo(box.right-18f*u,box.centerY())
                path.quadTo(box.right-18f*u,box.top+10f*u,box.left+20f*u,box.top+10f*u)
                canvas.drawPath(path,accent)
                drawArrowHead(canvas,box.left+20f*u,box.top+10f*u,180f,u)
            }
            Direction.ROUNDABOUT -> {
                val cx=box.centerX(); val cy=box.centerY()
                canvas.drawCircle(cx,cy,22f*u,accent)
                drawArrowHead(canvas,cx+22f*u,cy,0f,u)
            }
            Direction.UTURN -> {
                path.moveTo(box.centerX()+15f*u,box.bottom-8f*u)
                path.lineTo(box.centerX()+15f*u,box.top+28f*u)
                path.quadTo(box.centerX()+15f*u,box.top+6f*u,box.centerX()-8f*u,box.top+6f*u)
                path.quadTo(box.centerX()-30f*u,box.top+6f*u,box.centerX()-30f*u,box.top+28f*u)
                canvas.drawPath(path,accent)
                drawArrowHead(canvas,box.centerX()-30f*u,box.top+28f*u,90f,u)
            }
            Direction.STRAIGHT -> {
                path.moveTo(box.centerX(),box.bottom-8f*u)
                path.lineTo(box.centerX(),box.top+13f*u)
                canvas.drawPath(path,accent)
                drawArrowHead(canvas,box.centerX(),box.top+13f*u,-90f,u)
            }
        }
        accent.style = Paint.Style.FILL
    }

    private fun drawArrowHead(canvas: Canvas, x: Float, y: Float, degrees: Float, u: Float) {
        canvas.save()
        canvas.rotate(degrees,x,y)
        val p=Path().apply {
            moveTo(x+13f*u,y)
            lineTo(x-3f*u,y-10f*u)
            lineTo(x-3f*u,y+10f*u)
            close()
        }
        canvas.drawPath(p,accent)
        canvas.restore()
    }

    private fun drawPin(canvas: Canvas, cx: Float, cy: Float, u: Float, paint: Paint) {
        val old = paint.style
        paint.style = Paint.Style.STROKE
        canvas.drawCircle(cx, cy - 4f*u, 9f*u, paint)
        val p = Path().apply {
            moveTo(cx - 6f*u, cy + 2f*u)
            lineTo(cx, cy + 14f*u)
            lineTo(cx + 6f*u, cy + 2f*u)
        }
        canvas.drawPath(p, paint)
        paint.style = old
    }

    private fun drawRouteMiniIcon(canvas: Canvas, cx: Float, cy: Float, u: Float) {
        primary.style = Paint.Style.STROKE
        primary.strokeWidth = 3f*u
        primary.strokeCap = Paint.Cap.ROUND
        val p = Path().apply {
            moveTo(cx - 15f*u, cy - 12f*u)
            cubicTo(cx + 2f*u, cy - 8f*u, cx - 2f*u, cy + 9f*u, cx + 16f*u, cy + 12f*u)
        }
        canvas.drawPath(p, primary)
        primary.style = Paint.Style.FILL
    }

    private fun drawCoffeeIcon(canvas: Canvas, cx: Float, cy: Float, u: Float) {
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = 3f*u
        val cup = RectF(cx - 12f*u, cy - 8f*u, cx + 7f*u, cy + 9f*u)
        canvas.drawRoundRect(cup, 3f*u, 3f*u, accent)
        canvas.drawArc(RectF(cx + 4f*u, cy - 5f*u, cx + 17f*u, cy + 7f*u), -70f, 140f, false, accent)
        canvas.drawLine(cx - 15f*u, cy + 14f*u, cx + 15f*u, cy + 14f*u, accent)
        accent.style = Paint.Style.FILL
    }

    private fun drawChevron(canvas: Canvas, cx: Float, cy: Float, u: Float) {
        accent.style = Paint.Style.STROKE
        accent.strokeWidth = 3f*u
        accent.strokeCap = Paint.Cap.ROUND
        val p = Path().apply {
            moveTo(cx - 5f*u, cy - 9f*u)
            lineTo(cx + 4f*u, cy)
            lineTo(cx - 5f*u, cy + 9f*u)
        }
        canvas.drawPath(p, accent)
        accent.style = Paint.Style.FILL
    }

    private fun drawFlag(canvas: Canvas, x: Float, y: Float, u: Float) {
        primary.style = Paint.Style.STROKE
        primary.strokeWidth = 2.4f*u
        canvas.drawLine(x - 8f*u, y - 16f*u, x - 8f*u, y + 15f*u, primary)
        val flag = Path().apply {
            moveTo(x - 7f*u, y - 14f*u)
            lineTo(x + 12f*u, y - 10f*u)
            lineTo(x - 7f*u, y - 3f*u)
        }
        canvas.drawPath(flag, primary)
        primary.style = Paint.Style.FILL
    }

    private fun drawRoadIcon(canvas: Canvas, x: Float, y: Float, u: Float) {
        primary.style = Paint.Style.STROKE
        primary.strokeWidth = 2.6f*u
        val p = Path().apply {
            moveTo(x - 10f*u, y + 13f*u); lineTo(x - 3f*u, y - 13f*u)
            moveTo(x + 10f*u, y + 13f*u); lineTo(x + 3f*u, y - 13f*u)
        }
        canvas.drawPath(p, primary)
        primary.style = Paint.Style.FILL
    }

    private fun roundPanel(canvas: Canvas, rect: RectF, radius: Float, border: Boolean, warm: Boolean = false) {
        panel.color = if (warm && darkMode) Color.argb(244, 27, 16, 10) else if (darkMode) Color.argb(242, 7, 12, 18) else Color.argb(246, 250, 250, 248)
        canvas.drawRoundRect(rect, radius, radius, panel)
        if (border) {
            stroke.color = if (darkMode) ORANGE else Color.rgb(220,98,8)
            stroke.strokeWidth = 1.35f * unit()
            canvas.drawRoundRect(rect, radius, radius, stroke)
        }
    }

    private fun ellipsize(value: String, maxChars: Int): String =
        if (value.length <= maxChars) value else value.take((maxChars - 1).coerceAtLeast(1)) + "…"

    /** Base geometry against the locked 1280x600 map-surface reference. */
    private fun unit(): Float = min(width / 1280f, height / 600f).coerceIn(0.56f, 1.30f)
    private fun textUnit(): Float = unit().coerceIn(0.72f, 1.16f)

    companion object {
        private val ORANGE = Color.rgb(255,126,22)
        private val RED = Color.rgb(239,55,55)
        private val GREEN = Color.rgb(52,211,153)
    }
}
