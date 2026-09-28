package no.govia.mobile.car

import android.app.Presentation
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.location.Location
import android.view.View
import android.widget.FrameLayout
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import org.maplibre.android.MapLibre
import org.maplibre.android.annotations.Icon
import org.maplibre.android.annotations.IconFactory
import org.maplibre.android.annotations.Marker
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.annotations.Polyline
import org.maplibre.android.annotations.PolylineOptions
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/**
 * Real MapLibre renderer for Android Auto. Android Auto owns the Surface; this class
 * renders an actual MapView into it through a VirtualDisplay/Presentation as supported
 * by the Android for Cars Surface API.
 */
class GoViaCarMapSurface(
    private val context: Context,
    private val route: List<CarPoint>,
    private val recordingMode: Boolean = false,
) : SurfaceCallback {

    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var mapView: MapView? = null
    private var nightOverlay: View? = null
    private var cockpitOverlay: GoViaCarCockpitOverlayView? = null
    private var map: MapLibreMap? = null
    private var routeCasingPolyline: Polyline? = null
    private var routePolyline: Polyline? = null
    private var breadcrumbPolyline: Polyline? = null
    private var locationMarker: Marker? = null
    private var locationIcon: Icon? = null
    private var darkMode = true
    private var overlayMode = if (recordingMode) GoViaCarCockpitOverlayView.Mode.RECORDING else GoViaCarCockpitOverlayView.Mode.NAVIGATION
    private var homeOverlayState = GoViaCarCockpitOverlayView.HomeState()
    private var tripsOverlayState = GoViaCarCockpitOverlayView.TripsState()
    private var previewOverlayState = GoViaCarCockpitOverlayView.PreviewState()
    private var navigationOverlayState = GoViaCarCockpitOverlayView.NavigationState()
    private var recordingOverlayState = GoViaCarCockpitOverlayView.RecordingState()
    private var recordReadyOverlayState = GoViaCarCockpitOverlayView.RecordReadyState()
    private var latestLocation: Location? = null
    private var followBearing: Double? = null
    private var breadcrumb: List<CarPoint> = emptyList()
    private var stableArea = Rect()
    private var visibleArea = Rect()
    private val destroyed = AtomicBoolean(false)

    internal data class ControlCallbacks(
        val onSound: () -> Unit = {},
        val onZoomIn: () -> Unit = {},
        val onZoomOut: () -> Unit = {},
        val onRecenter: () -> Unit = {},
        val onStop: () -> Unit = {},
        val onOverlayAction: (GoViaCarCockpitOverlayView.Control) -> Unit = {},
    )

    private var controlCallbacks = ControlCallbacks()

    init {
        MapLibre.getInstance(context.applicationContext)
    }

    fun setDarkMode(enabled: Boolean) {
        if (darkMode == enabled) return
        darkMode = enabled
        cockpitOverlay?.darkMode = enabled
        updateNightOverlay()
        map?.let { loadStyle(it) }
    }


    internal fun updateHomeOverlay(state: GoViaCarCockpitOverlayView.HomeState) {
        overlayMode = GoViaCarCockpitOverlayView.Mode.HOME
        homeOverlayState = state
        cockpitOverlay?.apply { mode = overlayMode; homeState = state }
        applySafeArea()
    }

    internal fun updateTripsOverlay(state: GoViaCarCockpitOverlayView.TripsState) {
        overlayMode = GoViaCarCockpitOverlayView.Mode.TRIPS
        tripsOverlayState = state
        cockpitOverlay?.apply { mode = overlayMode; tripsState = state }
        applySafeArea()
    }

    internal fun updatePreviewOverlay(state: GoViaCarCockpitOverlayView.PreviewState) {
        overlayMode = GoViaCarCockpitOverlayView.Mode.PREVIEW
        previewOverlayState = state
        cockpitOverlay?.apply { mode = overlayMode; previewState = state }
        applySafeArea()
    }

    internal fun updateNavigationOverlay(state: GoViaCarCockpitOverlayView.NavigationState) {
        overlayMode = GoViaCarCockpitOverlayView.Mode.NAVIGATION
        navigationOverlayState = state
        cockpitOverlay?.apply { mode = overlayMode; navigationState = state }
        applySafeArea()
    }

    internal fun updateRecordReadyOverlay(state: GoViaCarCockpitOverlayView.RecordReadyState) {
        overlayMode = GoViaCarCockpitOverlayView.Mode.RECORD_READY
        recordReadyOverlayState = state
        cockpitOverlay?.apply { mode = overlayMode; recordReadyState = state }
        applySafeArea()
    }

    internal fun updateRecordingOverlay(state: GoViaCarCockpitOverlayView.RecordingState) {
        overlayMode = GoViaCarCockpitOverlayView.Mode.RECORDING
        recordingOverlayState = state
        cockpitOverlay?.apply { mode = overlayMode; recordingState = state }
        applySafeArea()
    }

    internal fun setControlCallbacks(callbacks: ControlCallbacks) {
        controlCallbacks = callbacks
    }

    fun updatePosition(location: Location?) {
        latestLocation = location?.let { Location(it) }
        renderDynamicState()
    }

    fun updateRecordingPath(points: List<CarPoint>) {
        breadcrumb = points.toList()
        renderDynamicState()
    }

    fun zoomBy(delta: Double) {
        val current = map ?: return
        current.animateCamera(CameraUpdateFactory.zoomBy(delta))
    }

    fun recenter() {
        val location = latestLocation
        if (location != null) moveCameraTo(location, animated = true) else frameRoute()
    }

    fun frameOverview() = frameRoute()

    fun close() {
        destroyed.set(true)
        releaseDisplay()
    }

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        val surface = surfaceContainer.surface ?: return
        if (!surface.isValid || surfaceContainer.width <= 0 || surfaceContainer.height <= 0) return
        releaseDisplay()
        destroyed.set(false)

        val displayManager = context.getSystemService(DisplayManager::class.java)
        virtualDisplay = displayManager.createVirtualDisplay(
            "GoViaAndroidAutoMap",
            surfaceContainer.width,
            surfaceContainer.height,
            surfaceContainer.dpi.coerceAtLeast(160),
            surface,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY,
        )

        val display = virtualDisplay?.display ?: return
        val p = Presentation(context, display)
        presentation = p

        val view = MapView(p.context)
        mapView = view
        view.onCreate(null)

        val root = FrameLayout(p.context)
        root.addView(
            view,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        val overlay = View(p.context).apply {
            isClickable = false
            isFocusable = false
        }
        nightOverlay = overlay
        root.addView(
            overlay,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        val cockpit = GoViaCarCockpitOverlayView(p.context).apply {
            isClickable = false
            isFocusable = false
            darkMode = this@GoViaCarMapSurface.darkMode
            mode = overlayMode
            homeState = homeOverlayState
            tripsState = tripsOverlayState
            previewState = previewOverlayState
            navigationState = navigationOverlayState
            recordingState = recordingOverlayState
            recordReadyState = recordReadyOverlayState
        }
        cockpitOverlay = cockpit
        root.addView(
            cockpit,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        updateNightOverlay()
        p.setContentView(root)
        p.show()
        view.onStart()
        view.onResume()
        view.getMapAsync { mapLibreMap ->
            if (destroyed.get()) return@getMapAsync
            map = mapLibreMap
            configureMap(mapLibreMap)
            loadStyle(mapLibreMap)
        }
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        destroyed.set(true)
        releaseDisplay()
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        this.visibleArea = Rect(visibleArea)
        applySafeArea()
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        this.stableArea = Rect(stableArea)
        applySafeArea()
    }

    override fun onScroll(distanceX: Float, distanceY: Float) {
        if (overlayMode == GoViaCarCockpitOverlayView.Mode.HOME || overlayMode == GoViaCarCockpitOverlayView.Mode.TRIPS || overlayMode == GoViaCarCockpitOverlayView.Mode.RECORD_READY) return
        map?.scrollBy(distanceX, distanceY)
    }

    override fun onClick(x: Float, y: Float) {
        when (cockpitOverlay?.controlAt(x, y)) {
            GoViaCarCockpitOverlayView.Control.SOUND -> controlCallbacks.onSound()
            GoViaCarCockpitOverlayView.Control.ZOOM_IN -> controlCallbacks.onZoomIn()
            GoViaCarCockpitOverlayView.Control.ZOOM_OUT -> controlCallbacks.onZoomOut()
            GoViaCarCockpitOverlayView.Control.RECENTER -> controlCallbacks.onRecenter()
            GoViaCarCockpitOverlayView.Control.STOP -> controlCallbacks.onStop()
            null -> Unit
            else -> cockpitOverlay?.controlAt(x, y)?.let(controlCallbacks.onOverlayAction)
        }
    }

    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        if (scaleFactor <= 0f) return
        val zoomDelta = kotlin.math.ln(scaleFactor.toDouble()) / kotlin.math.ln(2.0)
        zoomBy(zoomDelta)
    }

    private fun configureMap(map: MapLibreMap) {
        locationIcon = createLocationIcon()
        map.uiSettings.apply {
            isCompassEnabled = false
            isZoomGesturesEnabled = true
            isScrollGesturesEnabled = true
            isRotateGesturesEnabled = true
            isTiltGesturesEnabled = true
        }
        applySafeArea()
    }

    private fun loadStyle(map: MapLibreMap) {
        // Real theme switching: Liberty for day, OpenFreeMap Dark for night.
        // A subtle cool lift is applied only to the dark style so projected displays keep
        // road edges and labels readable without turning night mode back into the day map.
        val style = if (darkMode) DARK_STYLE else LIGHT_STYLE
        routeCasingPolyline = null
        routePolyline = null
        breadcrumbPolyline = null
        locationMarker = null
        map.setStyle(style) {
            if (destroyed.get()) return@setStyle
            drawRoute()
            renderDynamicState()
            if (latestLocation == null) frameRoute()
        }
    }

    private fun drawRoute() {
        val map = map ?: return
        routeCasingPolyline?.let { runCatching { map.removePolyline(it) } }
        routePolyline?.let { runCatching { map.removePolyline(it) } }
        routeCasingPolyline = null
        routePolyline = null
        if (route.size < 2 || recordingMode) return
        val points = route.map { LatLng(it.lat, it.lon) }
        routeCasingPolyline = map.addPolyline(
            PolylineOptions()
                .addAll(points)
                .color(if (darkMode) ROUTE_GLOW_DARK else ROUTE_GLOW_LIGHT)
                .width(8.5f)
        )
        routePolyline = map.addPolyline(
            PolylineOptions()
                .addAll(points)
                .color(ROUTE_ORANGE)
                .width(5.5f)
        )
    }

    private fun renderDynamicState() {
        val map = map ?: return
        val location = latestLocation
        if (location != null) {
            val position = LatLng(location.latitude, location.longitude)
            if (locationMarker == null) {
                locationMarker = map.addMarker(MarkerOptions().position(position).icon(locationIcon ?: createLocationIcon()))
            } else {
                locationMarker?.position = position
            }
            moveCameraTo(location, animated = false)
        }

        breadcrumbPolyline?.let { runCatching { map.removePolyline(it) } }
        breadcrumbPolyline = null
        if (recordingMode && breadcrumb.size >= 2) {
            breadcrumbPolyline = map.addPolyline(
                PolylineOptions()
                    .addAll(breadcrumb.map { LatLng(it.lat, it.lon) })
                    .color(RECORD_RED)
                    .width(8f)
            )
        }
    }

    private fun moveCameraTo(location: Location, animated: Boolean) {
        val map = map ?: return

        val gpsBearing = location.bearing.toDouble().takeIf { location.hasBearing() && it.isFinite() }
        val routeBearing = if (overlayMode == GoViaCarCockpitOverlayView.Mode.NAVIGATION) {
            routeBearingAt(location.latitude, location.longitude)
        } else null
        val rawBearing = gpsBearing
            ?: routeBearing
            ?: followBearing
            ?: map.cameraPosition.bearing
        val bearing = if (overlayMode == GoViaCarCockpitOverlayView.Mode.NAVIGATION) {
            smoothFollowBearing(rawBearing)
        } else {
            rawBearing
        }

        val isFollowMode = overlayMode == GoViaCarCockpitOverlayView.Mode.NAVIGATION
        val speedMps = if (location.hasSpeed()) location.speed.toDouble().coerceAtLeast(0.0) else 0.0
        val lookAheadMeters = if (isFollowMode) {
            (28.0 + speedMps * 2.2).coerceIn(28.0, 82.0)
        } else {
            0.0
        }
        val cameraTarget = if (isFollowMode && lookAheadMeters > 0.0) {
            pointAhead(location.latitude, location.longitude, bearing, lookAheadMeters)
        } else {
            LatLng(location.latitude, location.longitude)
        }

        // Follow/chase view for active navigation: the map looks forward over the vehicle
        // rather than straight down. Higher speed backs the camera off slightly.
        val zoom = if (isFollowMode) {
            when {
                speedMps >= 27.0 -> 15.6
                speedMps >= 20.0 -> 15.9
                speedMps >= 12.0 -> 16.2
                speedMps >= 5.0 -> 16.55
                else -> 16.8
            }
        } else {
            15.9
        }
        val tilt = if (isFollowMode) 60.0 else 28.0

        val target = CameraPosition.Builder()
            .target(cameraTarget)
            .zoom(zoom)
            .tilt(tilt)
            .bearing(bearing)
            .build()
        val update = CameraUpdateFactory.newCameraPosition(target)
        if (animated) map.animateCamera(update, 500) else map.moveCamera(update)
    }


    private fun routeBearingAt(lat: Double, lon: Double): Double? {
        if (route.size < 2) return null
        val latScale = cos(Math.toRadians(lat)).coerceAtLeast(0.2)
        var nearestIndex = 0
        var nearestDistance = Double.MAX_VALUE
        route.forEachIndexed { index, point ->
            val dx = (point.lon - lon) * latScale
            val dy = point.lat - lat
            val d2 = dx * dx + dy * dy
            if (d2 < nearestDistance) {
                nearestDistance = d2
                nearestIndex = index
            }
        }

        val fromIndex = when {
            nearestIndex >= route.lastIndex -> route.lastIndex - 1
            else -> nearestIndex
        }
        val toIndex = (fromIndex + 1).coerceAtMost(route.lastIndex)
        return bearingBetween(route[fromIndex], route[toIndex])
    }

    private fun bearingBetween(from: CarPoint, to: CarPoint): Double {
        val lat1 = Math.toRadians(from.lat)
        val lat2 = Math.toRadians(to.lat)
        val deltaLon = Math.toRadians(to.lon - from.lon)
        val y = sin(deltaLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return normalizeBearing(Math.toDegrees(atan2(y, x)))
    }

    private fun smoothFollowBearing(next: Double): Double {
        val previous = followBearing
        if (previous == null) {
            followBearing = normalizeBearing(next)
            return followBearing!!
        }
        var delta = normalizeBearing(next) - previous
        if (delta > 180.0) delta -= 360.0
        if (delta < -180.0) delta += 360.0
        val smoothed = normalizeBearing(previous + delta * 0.28)
        followBearing = smoothed
        return smoothed
    }

    private fun normalizeBearing(value: Double): Double = ((value % 360.0) + 360.0) % 360.0

    private fun pointAhead(lat: Double, lon: Double, bearingDegrees: Double, meters: Double): LatLng {
        val earthRadius = 6_378_137.0
        val angularDistance = meters / earthRadius
        val bearing = Math.toRadians(bearingDegrees)
        val lat1 = Math.toRadians(lat)
        val lon1 = Math.toRadians(lon)
        val lat2 = kotlin.math.asin(
            sin(lat1) * kotlin.math.cos(angularDistance) +
                cos(lat1) * sin(angularDistance) * cos(bearing),
        )
        val lon2 = lon1 + kotlin.math.atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            kotlin.math.cos(angularDistance) - sin(lat1) * sin(lat2),
        )
        return LatLng(Math.toDegrees(lat2), Math.toDegrees(lon2))
    }

    private fun frameRoute() {
        val map = map ?: return
        if (route.size < 2) return
        val builder = LatLngBounds.Builder()
        route.forEach { builder.include(LatLng(it.lat, it.lon)) }
        runCatching {
            map.moveCamera(CameraUpdateFactory.newLatLngBounds(builder.build(), 72))
        }
    }

    private fun applySafeArea() {
        val map = map ?: return
        val mapView = mapView ?: return
        val area = when {
            !stableArea.isEmpty -> stableArea
            !visibleArea.isEmpty -> visibleArea
            else -> null
        }
        if (mapView.width <= 0 || mapView.height <= 0) return
        val hostLeft = area?.left?.coerceAtLeast(0) ?: 0
        val hostTop = area?.top?.coerceAtLeast(0) ?: 0
        val hostRight = area?.let { (mapView.width - it.right).coerceAtLeast(0) } ?: 0
        val bottom = area?.let { (mapView.height - it.bottom).coerceAtLeast(0) } ?: 0

        // Locked cockpit framing: guidance occupies the left third, while the vehicle sits
        // low enough to expose substantially more route ahead than behind.
        val guidanceLeft = if (overlayMode == GoViaCarCockpitOverlayView.Mode.NAVIGATION) {
            (mapView.width * 0.18f).toInt()
        } else 0
        val guidanceTop = if (overlayMode == GoViaCarCockpitOverlayView.Mode.NAVIGATION) {
            (mapView.height * 0.47f).toInt()
        } else 0
        val controlRight = if (overlayMode == GoViaCarCockpitOverlayView.Mode.NAVIGATION) {
            (mapView.width * 0.04f).toInt()
        } else 0
        val left = maxOf(hostLeft, guidanceLeft)
        val top = maxOf(hostTop, guidanceTop)
        val right = maxOf(hostRight, controlRight)
        @Suppress("DEPRECATION")
        map.setPadding(left, top, right, bottom)
    }

    private fun updateNightOverlay() {
        nightOverlay?.setBackgroundColor(
            if (darkMode) NIGHT_LIFT else Color.TRANSPARENT,
        )
        cockpitOverlay?.darkMode = darkMode
    }

    private fun createLocationIcon(): Icon {
        val size = 72
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(185, 255, 255, 255) }
        canvas.drawCircle(size / 2f, size / 2f, 31f, halo)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(32, 39, 44)
            style = Paint.Style.STROKE
            strokeWidth = 3.5f
        }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ROUTE_ORANGE }
        val path = Path().apply {
            moveTo(size / 2f, 11f)
            lineTo(16f, 57f)
            lineTo(size / 2f, 47f)
            lineTo(56f, 57f)
            close()
        }
        canvas.drawPath(path, fill)
        canvas.drawPath(path, border)
        return IconFactory.getInstance(context).fromBitmap(bitmap)
    }

    private fun releaseDisplay() {
        map = null
        routeCasingPolyline = null
        routePolyline = null
        breadcrumbPolyline = null
        locationMarker = null
        locationIcon = null
        mapView?.let { view ->
            runCatching { view.onPause() }
            runCatching { view.onStop() }
            runCatching { view.onDestroy() }
        }
        mapView = null
        nightOverlay = null
        cockpitOverlay = null
        runCatching { presentation?.dismiss() }
        presentation = null
        runCatching { virtualDisplay?.release() }
        virtualDisplay = null
    }

    companion object {
        private const val LIGHT_STYLE = "https://tiles.openfreemap.org/styles/liberty"
        private const val DARK_STYLE = "https://tiles.openfreemap.org/styles/dark"
        private val NIGHT_LIFT = Color.argb(42, 255, 255, 255)
        private val ROUTE_ORANGE = Color.rgb(255, 126, 22)
        private val ROUTE_GLOW_DARK = Color.argb(245, 74, 34, 0)
        private val ROUTE_GLOW_LIGHT = Color.argb(190, 255, 236, 210)
        private val RECORD_RED = Color.rgb(244, 63, 94)
    }
}
