package no.govia.mobile.car

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import java.util.Locale
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

class GoViaCarRecordingCockpitScreen(carContext: CarContext, private val mapSurface: GoViaCarMapSurface) : Screen(carContext), LocationListener, DefaultLifecycleObserver {
    private val repo = GoViaCarRepository(carContext)
    private val locationManager = carContext.getSystemService(LocationManager::class.java)
    private val track = mutableListOf<CarPoint>()
    private var currentLocation: Location? = null
    private var startedAt = System.currentTimeMillis()
    private var distanceMeters = 0.0

    init {
        lifecycle.addObserver(this)
    }

    override fun onStart(owner: LifecycleOwner) {
        mapSurface.updateRoute(emptyList())
        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.setControlCallbacks(
            GoViaCarMapSurface.ControlCallbacks(
                onZoomIn = { mapSurface.zoomBy(1.0) },
                onZoomOut = { mapSurface.zoomBy(-1.0) },
                onRecenter = { mapSurface.recenter() },
                onStop = { requestStopRecordingConfirmation() },
            )
        )
        mapSurface.updateRecordingOverlay(
            GoViaCarCockpitOverlayView.RecordingState(
                elapsed = formatElapsed(elapsedSeconds()),
                distance = formatDistance(distanceMeters.roundToInt()),
                gpsActive = currentLocation != null,
            )
        )
        if (ContextCompat.checkSelfPermission(carContext, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
        runCatching { locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 3f, this) }
        runCatching { locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 2500L, 8f, this) }
        runCatching { locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull()?.let(::onLocationChanged)
        runCatching { locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull()?.let { if (currentLocation == null) onLocationChanged(it) }
    }

    override fun onStop(owner: LifecycleOwner) {
        runCatching { locationManager.removeUpdates(this) }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        runCatching { locationManager.removeUpdates(this) }
    }

    override fun onLocationChanged(location: Location) {
        currentLocation?.let { previous ->
            distanceMeters += haversine(previous.latitude, previous.longitude, location.latitude, location.longitude)
        }
        currentLocation = Location(location)
        val point = CarPoint(location.longitude, location.latitude)
        if (track.isEmpty() || haversine(track.last().lat, track.last().lon, point.lat, point.lon) >= 5.0) track += point
        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.updateRecordingPath(track)
        mapSurface.updatePosition(location)
        invalidate()
    }

    override fun onGetTemplate(): Template {
        val dark = resolveDarkMode()
        mapSurface.setDarkMode(dark)
        val seconds = elapsedSeconds()
        mapSurface.updateRecordingOverlay(
            GoViaCarCockpitOverlayView.RecordingState(
                elapsed = formatElapsed(seconds),
                distance = formatDistance(distanceMeters.roundToInt()),
                gpsActive = currentLocation != null,
            )
        )

        // Keep recording on the same GoVia-owned cockpit control system as navigation.
        // The host gets only the required invisible strip; recenter/zoom/stop are drawn on
        // the map surface so there are no duplicate grey Android Auto controls.
        return NavigationTemplate.Builder()
            .setActionStrip(GoViaCarTemplateCompat.invisibleRequiredActionStrip())
            .build()
    }


    private fun requestStopRecordingConfirmation() {
        screenManager.push(
            GoViaCarStopRecordingConfirmScreen(carContext) {
                stopRecording()
            }
        )
    }

    private fun stopRecording() {
        val intent = Intent(carContext, CarRideRecordingService::class.java).apply {
            action = CarRideRecordingService.ACTION_STOP
        }
        carContext.startService(intent)
        repo.setRecording(false)
        screenManager.popToRoot()
    }

    private fun resolveDarkMode(): Boolean = when (repo.readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> (carContext.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }

    private fun elapsedSeconds(): Int = max(0, ((System.currentTimeMillis() - startedAt) / 1000L).toInt())

    private fun formatElapsed(totalSeconds: Int): String {
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) String.format(Locale("nb", "NO"), "%d:%02d:%02d", hours, minutes, seconds)
        else String.format(Locale("nb", "NO"), "%02d:%02d", minutes, seconds)
    }

    private fun formatDistance(meters: Int): String = if (meters >= 1000) {
        String.format(Locale("nb", "NO"), "%.1f km", meters / 1000.0)
    } else "$meters m"

    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371000.0
        val p1 = Math.toRadians(lat1)
        val p2 = Math.toRadians(lat2)
        val dp = Math.toRadians(lat2 - lat1)
        val dl = Math.toRadians(lon2 - lon1)
        val a = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit
    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
}
