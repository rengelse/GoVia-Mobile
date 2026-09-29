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
import android.util.Log
import android.view.View
import android.view.Surface
import android.view.Gravity
import android.widget.FrameLayout
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.core.content.ContextCompat
import no.govia.mobile.R
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
    initialRoute: List<CarPoint> = emptyList(),
) : SurfaceCallback {

    companion object {
        private const val SPEED_LIMIT_DIAG_TAG = "GoViaSpeedLimitDiag"
    }

    enum class DisplayMode { BROWSE, PREVIEW, NAVIGATION, RECORDING }
    enum class NavigationCameraMode { PERSPECTIVE, NORTH_UP, OVERVIEW }

    private var route: List<CarPoint> = initialRoute.toList()
    private var waypoints: List<CarWaypoint> = emptyList()
    private var virtualDisplay: VirtualDisplay? = null
    private var hostSurface: Surface? = null
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var surfaceDpi = 0
    private var presentation: Presentation? = null
    private var mapView: MapView? = null
    private var nightOverlay: View? = null
    private var speedLimitView: GoViaSpeedLimitView? = null
    private var map: MapLibreMap? = null
    private var routeCasingPolyline: Polyline? = null
    private var routePolyline: Polyline? = null
    private var breadcrumbPolyline: Polyline? = null
    private var locationMarker: Marker? = null
    private var waypointMarkers: List<Marker> = emptyList()
    private var locationIcon: Icon? = null
    private var darkMode = true
    private var displayMode = DisplayMode.BROWSE
    private var navigationCameraMode = NavigationCameraMode.PERSPECTIVE
    private var lastFollowCameraMode = NavigationCameraMode.PERSPECTIVE
    private var latestLocation: Location? = null
    private var currentSpeedLimitKph: Int? = null
    private var followBearing: Double? = null
    private var breadcrumb: List<CarPoint> = emptyList()
    private var stableArea = Rect()
    private var visibleArea = Rect()
    private val destroyed = AtomicBoolean(false)

    init {
        MapLibre.getInstance(context.applicationContext)
    }

    internal fun setDisplayMode(mode: DisplayMode) {
        if (displayMode == mode) return
        displayMode = mode
        applySafeArea()
        updateSpeedLimitOverlay()
        renderDynamicState()
    }


    internal fun updateRoute(points: List<CarPoint>) {
        val next = points.toList()
        if (route == next) return
        route = next
        routeCasingPolyline?.let { map?.removePolyline(it) }
        routePolyline?.let { map?.removePolyline(it) }
        routeCasingPolyline = null
        routePolyline = null
        if (map != null) drawRoute()
        if (route.size >= 2 && (latestLocation == null || navigationCameraMode == NavigationCameraMode.OVERVIEW)) frameRoute()
    }

    internal fun updateWaypoints(items: List<CarWaypoint>) {
        val next = items.filter { it.location != null }
        if (waypoints == next) return
        waypoints = next
        clearWaypointMarkers()
        if (map != null) drawWaypoints()
    }

    fun setDarkMode(enabled: Boolean) {
        if (darkMode == enabled) return
        darkMode = enabled
        updateNightOverlay()
        map?.let { loadStyle(it) }
    }


    fun updatePosition(location: Location?) {
        latestLocation = location?.let { Location(it) }
        renderDynamicState()
    }

    fun updateSpeedLimit(speedLimitKph: Int?) {
        val normalized = speedLimitKph?.takeIf { it in 1..200 }
        if (normalized != currentSpeedLimitKph) {
            Log.i(
                SPEED_LIMIT_DIAG_TAG,
                "mapSurface received=$speedLimitKph normalized=$normalized displayMode=$displayMode viewReady=${speedLimitView != null}",
            )
        }
        currentSpeedLimitKph = normalized
        updateSpeedLimitOverlay()
    }

    fun currentNavigationCameraMode(): NavigationCameraMode = navigationCameraMode

    fun cycleNavigationCameraMode(): NavigationCameraMode {
        val next = when (navigationCameraMode) {
            NavigationCameraMode.PERSPECTIVE -> NavigationCameraMode.NORTH_UP
            NavigationCameraMode.NORTH_UP -> NavigationCameraMode.OVERVIEW
            NavigationCameraMode.OVERVIEW -> NavigationCameraMode.PERSPECTIVE
        }
        setNavigationCameraMode(next)
        return next
    }

    fun setNavigationCameraMode(mode: NavigationCameraMode) {
        if (mode != NavigationCameraMode.OVERVIEW) lastFollowCameraMode = mode
        navigationCameraMode = mode
        applyNavigationCameraMode(animated = true)
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
        if (navigationCameraMode == NavigationCameraMode.OVERVIEW) {
            navigationCameraMode = lastFollowCameraMode
        }
        val location = latestLocation
        if (location != null) moveCameraTo(location, animated = true) else frameRoute()
    }

    fun frameOverview() {
        setNavigationCameraMode(NavigationCameraMode.OVERVIEW)
    }

    fun close() {
        destroyed.set(true)
        releaseDisplay()
    }

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        val surface = surfaceContainer.surface ?: return
        if (!surface.isValid || surfaceContainer.width <= 0 || surfaceContainer.height <= 0) return
        destroyed.set(false)

        // Android Auto may call onSurfaceAvailable repeatedly when only size/DPI changes.
        // Keep the existing MapView/Presentation alive and resize/rebind the VirtualDisplay
        // instead of tearing the whole renderer down on every callback.
        val existingDisplay = virtualDisplay
        if (existingDisplay != null && presentation != null && mapView != null) {
            val surfaceChanged = hostSurface !== surface
            if (surfaceChanged) {
                runCatching { existingDisplay.setSurface(surface) }
                runCatching { hostSurface?.release() }
                hostSurface = surface
            }
            if (surfaceWidth != surfaceContainer.width ||
                surfaceHeight != surfaceContainer.height ||
                surfaceDpi != surfaceContainer.dpi
            ) {
                runCatching {
                    existingDisplay.resize(
                        surfaceContainer.width,
                        surfaceContainer.height,
                        surfaceContainer.dpi.coerceAtLeast(160),
                    )
                }
            }
            surfaceWidth = surfaceContainer.width
            surfaceHeight = surfaceContainer.height
            surfaceDpi = surfaceContainer.dpi
            applySafeArea()
            renderDynamicState()
            return
        }

        hostSurface = surface
        surfaceWidth = surfaceContainer.width
        surfaceHeight = surfaceContainer.height
        surfaceDpi = surfaceContainer.dpi

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
        val speedSign = GoViaSpeedLimitView(p.context)
        speedLimitView = speedSign
        val signSize = dp(72)
        root.addView(
            speedSign,
            FrameLayout.LayoutParams(signSize, signSize, Gravity.END or Gravity.BOTTOM),
        )
        // Android Auto templates own maneuver/ETA/actions. The map surface only adds
        // navigation-map content that belongs in the safe area, currently the road speed limit.
        updateNightOverlay()
        updateSpeedLimitOverlay()
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
        // This is the only host callback that tears the renderer down.
        // Detach the host surface before releasing the VirtualDisplay/MapView.
        runCatching { virtualDisplay?.setSurface(null) }
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
        if (displayMode == DisplayMode.BROWSE) return
        map?.scrollBy(distanceX, distanceY)
    }

    override fun onClick(x: Float, y: Float) = Unit

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
        waypointMarkers = emptyList()
        map.setStyle(style) {
            if (destroyed.get()) return@setStyle
            drawRoute()
            drawWaypoints()
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
        if (route.size < 2 || displayMode == DisplayMode.RECORDING) return
        val points = route.map { LatLng(it.lat, it.lon) }
        routeCasingPolyline = map.addPolyline(
            PolylineOptions()
                .addAll(points)
                .color(if (darkMode) ROUTE_GLOW_DARK else ROUTE_GLOW_LIGHT)
                .width(11.0f)
        )
        routePolyline = map.addPolyline(
            PolylineOptions()
                .addAll(points)
                .color(ROUTE_ORANGE)
                .width(6.5f)
        )
    }

    private fun clearWaypointMarkers() {
        val currentMap = map
        if (currentMap != null) waypointMarkers.forEach { marker -> runCatching { currentMap.removeMarker(marker) } }
        waypointMarkers = emptyList()
    }

    private fun drawWaypoints() {
        val currentMap = map ?: return
        clearWaypointMarkers()
        waypointMarkers = waypoints.mapNotNull { waypoint ->
            val point = waypoint.location ?: return@mapNotNull null
            runCatching {
                currentMap.addMarker(
                    MarkerOptions()
                        .position(LatLng(point.lat, point.lon))
                        .title(waypoint.name)
                        .snippet(listOf(waypoint.category, waypoint.kind).filter { it.isNotBlank() }.joinToString(" · "))
                )
            }.getOrNull()
        }
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
        if (displayMode == DisplayMode.RECORDING && breadcrumb.size >= 2) {
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
        if (displayMode == DisplayMode.NAVIGATION && navigationCameraMode == NavigationCameraMode.OVERVIEW) return

        val gpsBearing = location.bearing.toDouble().takeIf { location.hasBearing() && it.isFinite() }
        val routeBearing = if (displayMode == DisplayMode.NAVIGATION) {
            routeBearingAt(location.latitude, location.longitude)
        } else null
        val rawBearing = gpsBearing
            ?: routeBearing
            ?: followBearing
            ?: map.cameraPosition.bearing

        val isNavigation = displayMode == DisplayMode.NAVIGATION
        val isPerspective = isNavigation && navigationCameraMode == NavigationCameraMode.PERSPECTIVE
        val isNorthUp = isNavigation && navigationCameraMode == NavigationCameraMode.NORTH_UP
        val bearing = when {
            isNorthUp -> 0.0
            isPerspective -> smoothFollowBearing(rawBearing)
            else -> rawBearing
        }

        val speedMps = if (location.hasSpeed()) location.speed.toDouble().coerceAtLeast(0.0) else 0.0
        val lookAheadMeters = if (isPerspective) {
            (28.0 + speedMps * 2.2).coerceIn(28.0, 82.0)
        } else {
            0.0
        }
        val cameraTarget = if (lookAheadMeters > 0.0) {
            pointAhead(location.latitude, location.longitude, bearing, lookAheadMeters)
        } else {
            LatLng(location.latitude, location.longitude)
        }

        val zoom = if (isNavigation) {
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
        val tilt = when {
            isPerspective -> 60.0
            isNorthUp -> 0.0
            else -> 28.0
        }

        val target = CameraPosition.Builder()
            .target(cameraTarget)
            .zoom(zoom)
            .tilt(tilt)
            .bearing(bearing)
            .build()
        val update = CameraUpdateFactory.newCameraPosition(target)
        if (animated) map.animateCamera(update, 500) else map.moveCamera(update)
    }

    private fun applyNavigationCameraMode(animated: Boolean) {
        if (displayMode != DisplayMode.NAVIGATION) return
        if (navigationCameraMode == NavigationCameraMode.OVERVIEW) {
            frameRoute(animated)
            return
        }
        latestLocation?.let { moveCameraTo(it, animated) }
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

    private fun frameRoute(animated: Boolean = false) {
        val map = map ?: return
        if (route.size < 2) return
        val builder = LatLngBounds.Builder()
        route.forEach { builder.include(LatLng(it.lat, it.lon)) }
        runCatching {
            val update = CameraUpdateFactory.newLatLngBounds(builder.build(), 72)
            if (animated) map.animateCamera(update, 500) else map.moveCamera(update)
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
        val left = area?.left?.coerceAtLeast(0) ?: 0
        val top = area?.top?.coerceAtLeast(0) ?: 0
        val right = area?.let { (mapView.width - it.right).coerceAtLeast(0) } ?: 0
        val bottom = area?.let { (mapView.height - it.bottom).coerceAtLeast(0) } ?: 0
        @Suppress("DEPRECATION")
        map.setPadding(left, top, right, bottom)
        speedLimitView?.let { view ->
            val params = view.layoutParams as? FrameLayout.LayoutParams ?: return@let
            params.rightMargin = right + dp(18)
            params.bottomMargin = bottom + dp(18)
            view.layoutParams = params
        }
    }

    private fun updateSpeedLimitOverlay() {
        val rendered = if (displayMode == DisplayMode.NAVIGATION) currentSpeedLimitKph else null
        speedLimitView?.speedLimitKph = rendered
        Log.d(
            SPEED_LIMIT_DIAG_TAG,
            "overlay rendered=$rendered displayMode=$displayMode viewReady=${speedLimitView != null}",
        )
    }

    private fun dp(value: Int): Int = (value * context.resources.displayMetrics.density).toInt().coerceAtLeast(value)

    private fun updateNightOverlay() {
        nightOverlay?.setBackgroundColor(
            if (darkMode) NIGHT_LIFT else Color.TRANSPARENT,
        )
    }

    private fun createLocationIcon(): Icon {
        // The vehicle marker is the real GoVia application icon, not a generic navigation arrow.
        val size = 78
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(215, 255, 255, 255) }
        canvas.drawCircle(size / 2f, size / 2f, 35f, halo)
        val icon = ContextCompat.getDrawable(context, R.mipmap.ic_launcher)
        if (icon != null) {
            val inset = 8
            icon.setBounds(inset, inset, size - inset, size - inset)
            icon.draw(canvas)
        } else {
            val fallback = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ROUTE_ORANGE }
            canvas.drawCircle(size / 2f, size / 2f, 24f, fallback)
        }
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
        speedLimitView = null
        runCatching { presentation?.dismiss() }
        presentation = null
        runCatching { virtualDisplay?.setSurface(null) }
        runCatching { virtualDisplay?.release() }
        virtualDisplay = null
        runCatching { hostSurface?.release() }
        hostSurface = null
        surfaceWidth = 0
        surfaceHeight = 0
        surfaceDpi = 0
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
