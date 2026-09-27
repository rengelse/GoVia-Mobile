package no.govia.mobile.car

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Distance
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
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

class GoViaCarRecordingCockpitScreen(carContext: CarContext) : Screen(carContext), LocationListener, DefaultLifecycleObserver {
    private val repo = GoViaCarRepository(carContext)
    private val locationManager = carContext.getSystemService(LocationManager::class.java)
    private val appManager = carContext.getCarService(AppManager::class.java)
    private val renderer = GoViaRouteSurfaceRenderer(emptyList())
    private val track = mutableListOf<CarPoint>()
    private var currentLocation: Location? = null
    private var startedAt = System.currentTimeMillis()
    private var distanceMeters = 0.0

    init {
        lifecycle.addObserver(this)
        appManager.setSurfaceCallback(renderer)
        renderer.setDarkMode(resolveDarkMode())
        renderer.updateUiState(buildSurfaceState())
    }

    override fun onStart(owner: LifecycleOwner) {
        if (ContextCompat.checkSelfPermission(carContext, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
        runCatching { locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 3f, this) }
        runCatching { locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 2500L, 8f, this) }
        runCatching { locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER) }?.getOrNull()?.let { onLocationChanged(it) }
        runCatching { locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }?.getOrNull()?.let { if (currentLocation == null) onLocationChanged(it) }
    }

    override fun onStop(owner: LifecycleOwner) {
        runCatching { locationManager.removeUpdates(this) }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        runCatching { locationManager.removeUpdates(this) }
        appManager.setSurfaceCallback(null)
    }

    override fun onLocationChanged(location: Location) {
        currentLocation?.let { previous -> distanceMeters += haversine(previous.latitude, previous.longitude, location.latitude, location.longitude) }
        currentLocation = location
        val point = CarPoint(location.longitude, location.latitude)
        if (track.isEmpty() || haversine(track.last().lat, track.last().lon, point.lat, point.lon) >= 5.0) track += point
        renderer.setDarkMode(resolveDarkMode())
        renderer.updateRecordingPath(track.toList())
        renderer.updateUiState(buildSurfaceState())
        invalidate()
    }

    override fun onGetTemplate(): Template {
        renderer.setDarkMode(resolveDarkMode())
        renderer.updateUiState(buildSurfaceState())
        val routing = RoutingInfo.Builder()
            .setCurrentStep(Step.Builder("Opptak pågår").setRoad("REC aktiv").build(), displayDistance(distanceMeters))
            .build()
        val actions = ActionStrip.Builder()
            .addAction(
                Action.Builder()
                    .setTitle("Stopp og lagre")
                    .setOnClickListener { stopRecording() }
                    .build()
            )
            .build()
        return NavigationTemplate.Builder()
            .setNavigationInfo(routing)
            .setActionStrip(actions)
            .build()
    }

    private fun buildSurfaceState(): GoViaRouteSurfaceRenderer.GoViaSurfaceUiState {
        val point = currentLocation?.let { CarPoint(it.longitude, it.latitude) }
        val seconds = max(0, ((System.currentTimeMillis() - startedAt) / 1000L).toInt())
        return GoViaRouteSurfaceRenderer.GoViaSurfaceUiState(
            title = "Opptak pågår",
            subtitle = "GPS-spor lagres lokalt mens du kjører",
            infoTitle = "REC",
            infoLine = "${formatElapsed(seconds)} · ${formatDistance(distanceMeters.roundToInt())}",
            currentPoint = point,
            headingDegrees = currentLocation?.takeIf { it.hasBearing() }?.bearing ?: 0f,
            etaText = formatElapsed(seconds),
            remainingText = formatDistance(distanceMeters.roundToInt()),
            recording = true,
            recordingFooter = "REC · ${formatElapsed(seconds)} · ${formatDistance(distanceMeters.roundToInt())}",
        )
    }

    private fun stopRecording() {
        val intent = Intent(carContext, CarRideRecordingService::class.java).apply {
            action = CarRideRecordingService.ACTION_STOP
        }
        carContext.startService(intent)
        repo.setRecording(false)
        screenManager.pop()
    }

    private fun resolveDarkMode(): Boolean {
        return when (repo.readState().themeMode) {
            "light" -> false
            "dark" -> true
            else -> (carContext.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        }
    }

    private fun displayDistance(meters: Double): Distance = if (meters >= 1000) {
        Distance.create(meters / 1000.0, Distance.UNIT_KILOMETERS_P1)
    } else {
        Distance.create(max(0.0, meters), Distance.UNIT_METERS)
    }

    private fun formatDistance(meters: Int): String = if (meters >= 1000) String.format(Locale("nb", "NO"), "%.1f km", meters / 1000.0) else "$meters m"

    private fun formatElapsed(totalSeconds: Int): String {
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) String.format(Locale("nb", "NO"), "%d:%02d:%02d", hours, minutes, seconds)
        else String.format(Locale("nb", "NO"), "%02d:%02d", minutes, seconds)
    }

    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371000.0
        val p1 = Math.toRadians(lat1); val p2 = Math.toRadians(lat2)
        val dp = Math.toRadians(lat2 - lat1); val dl = Math.toRadians(lon2 - lon1)
        val a = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit
    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
}
