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
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import no.govia.mobile.R
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
    private val mapSurface = GoViaCarMapSurface(carContext, emptyList(), recordingMode = true)
    private val track = mutableListOf<CarPoint>()
    private var currentLocation: Location? = null
    private var startedAt = System.currentTimeMillis()
    private var distanceMeters = 0.0

    init {
        lifecycle.addObserver(this)
        appManager.setSurfaceCallback(mapSurface)
        mapSurface.setDarkMode(resolveDarkMode())
    }

    override fun onStart(owner: LifecycleOwner) {
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
        appManager.setSurfaceCallback(null)
        mapSurface.close()
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
        mapSurface.setDarkMode(resolveDarkMode())
        val seconds = elapsedSeconds()
        val gpsText = if (currentLocation != null) "GPS aktiv" else "Venter på GPS"

        val pane = Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle("● REC · Opptak pågår")
                    .addText("${formatElapsed(seconds)} · ${formatDistance(distanceMeters.roundToInt())}")
                    .build()
            )
            .addRow(
                Row.Builder()
                    .setTitle(gpsText)
                    .addText("Spor lagres lokalt og tegnes fortløpende på kartet")
                    .build()
            )
            .addAction(
                Action.Builder()
                    .setTitle("Stopp og lagre")
                    .setOnClickListener { stopRecording() }
                    .build()
            )
            .build()

        val content = PaneTemplate.Builder(pane)
            .setTitle("Ta opp tur")
            .setHeaderAction(Action.BACK)
            .build()

        if (carContext.carAppApiLevel < 7) return content

        val mapActions = ActionStrip.Builder()
            .addAction(Action.PAN)
            .addAction(iconAction(R.drawable.ic_car_recenter) { mapSurface.recenter() })
            .addAction(iconAction(R.drawable.ic_car_zoom_in) { mapSurface.zoomBy(1.0) })
            .addAction(iconAction(R.drawable.ic_car_zoom_out) { mapSurface.zoomBy(-1.0) })
            .build()

        return MapWithContentTemplate.Builder()
            .setContentTemplate(content)
            .setMapController(MapController.Builder().setMapActionStrip(mapActions).build())
            .build()
    }

    private fun iconAction(drawable: Int, action: () -> Unit): Action =
        Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build())
            .setOnClickListener(action)
            .build()

    private fun stopRecording() {
        val intent = Intent(carContext, CarRideRecordingService::class.java).apply {
            action = CarRideRecordingService.ACTION_STOP
        }
        carContext.startService(intent)
        repo.setRecording(false)
        screenManager.pop()
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
