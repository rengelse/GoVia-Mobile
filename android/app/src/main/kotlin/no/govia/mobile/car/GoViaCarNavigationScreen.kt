package no.govia.mobile.car

import android.Manifest
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.speech.tts.TextToSpeech
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Distance
import androidx.car.app.model.Template
import androidx.car.app.navigation.NavigationManager
import androidx.car.app.navigation.NavigationManagerCallback
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
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

class GoViaCarNavigationScreen(
    carContext: CarContext,
    private val trip: CarTrip
) : Screen(carContext), LocationListener, DefaultLifecycleObserver, TextToSpeech.OnInitListener {

    private val repo = GoViaCarRepository(carContext)
    private val state = repo.readState()
    private val locationManager = carContext.getSystemService(LocationManager::class.java)
    private val appManager = carContext.getCarService(AppManager::class.java)
    private val navigationManager = carContext.getCarService(NavigationManager::class.java)
    private val geometry = trip.stages.flatMap { it.geometry }
    private val cumulative = cumulativeDistances(geometry)
    private val maneuvers = buildManeuvers(trip.stages)
    private val renderer = GoViaRouteSurfaceRenderer(geometry)
    private var tts: TextToSpeech? = null
    private var currentLocation: Location? = null
    private var progressMeters = 0.0
    private var currentManeuver: OverallManeuver? = null
    private val announced = mutableSetOf<String>()
    private var announcedPoiId: String? = null
    private var currentPoiBanner: String? = null

    init {
        lifecycle.addObserver(this)
        appManager.setSurfaceCallback(renderer)
        navigationManager.setNavigationManagerCallback(object : NavigationManagerCallback {
            override fun onStopNavigation() { stopNavigation() }
        })
        navigationManager.navigationStarted()
        renderer.setDarkMode(resolveDarkMode())
        renderer.updateUiState(buildSurfaceState())
        if (state.voiceEnabled) tts = TextToSpeech(carContext, this)
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
        runCatching { navigationManager.navigationEnded() }
        appManager.setSurfaceCallback(null)
        tts?.stop(); tts?.shutdown(); tts = null
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        val engine = tts ?: return
        val nb = engine.setLanguage(Locale.forLanguageTag("nb-NO"))
        if (nb < TextToSpeech.LANG_AVAILABLE) engine.setLanguage(Locale.forLanguageTag("no-NO"))
        speak("Navigasjon startet.")
    }

    override fun onLocationChanged(location: Location) {
        currentLocation = location
        progressMeters = nearestProgress(location.latitude, location.longitude)
        currentManeuver = maneuvers.firstOrNull { it.distanceFromStartMeters >= progressMeters - 20.0 }
        val poi = state.pois
            .filter { it.distanceMeters >= progressMeters }
            .minByOrNull { it.distanceMeters }
            ?.takeIf { it.distanceMeters - progressMeters <= poiThreshold(it.category) }
        currentPoiBanner = poi?.let { "${it.name} – ${formatDistance((it.distanceMeters - progressMeters).roundToInt())}" }
        renderer.setDarkMode(resolveDarkMode())
        renderer.updateUiState(buildSurfaceState())
        maybeAnnounceManeuver()
        if (poi != null && announcedPoiId != poi.id) {
            announcedPoiId = poi.id
            speak("Du nærmer deg ${poi.name}, om ${spokenDistance((poi.distanceMeters - progressMeters).roundToInt())}.")
        }
        invalidate()
    }

    override fun onGetTemplate(): Template {
        renderer.setDarkMode(resolveDarkMode())
        renderer.updateUiState(buildSurfaceState())
        val maneuver = currentManeuver
        val distanceToTurn = max(0.0, (maneuver?.distanceFromStartMeters ?: progressMeters) - progressMeters)
        val step = Step.Builder(maneuver?.instruction ?: "Følg ruten")
            .apply { maneuver?.roadName?.takeIf { it.isNotBlank() }?.let { setRoad(it) } }
            .build()
        val routing = RoutingInfo.Builder()
            .setCurrentStep(step, displayDistance(distanceToTurn))
            .apply {
                maneuvers.firstOrNull { it.distanceFromStartMeters > (maneuver?.distanceFromStartMeters ?: -1.0) }
                    ?.let { setNextStep(Step.Builder(it.instruction).build()) }
            }
            .build()
        val actionStrip = ActionStrip.Builder()
            .addAction(
                Action.Builder()
                    .setTitle("Stopp")
                    .setOnClickListener { stopNavigation() }
                    .build()
            )
            .build()
        return NavigationTemplate.Builder()
            .setNavigationInfo(routing)
            .setActionStrip(actionStrip)
            .build()
    }

    private fun buildSurfaceState(): GoViaRouteSurfaceRenderer.GoViaSurfaceUiState {
        val location = currentLocation
        val maneuver = currentManeuver
        val distanceToTurn = max(0.0, (maneuver?.distanceFromStartMeters ?: progressMeters) - progressMeters)
        val heading = when {
            location == null -> 0f
            location.hasBearing() -> location.bearing
            else -> 0f
        }
        return GoViaRouteSurfaceRenderer.GoViaSurfaceUiState(
            title = if (maneuver == null) "Følg ruten" else "${formatDistance(distanceToTurn.roundToInt())}",
            subtitle = if (maneuver == null) trip.name else listOfNotNull(
                maneuver.instruction.takeIf { it.isNotBlank() },
                maneuver.roadName.takeIf { it.isNotBlank() }?.let { if (maneuver.instruction.contains(it, ignoreCase = true)) null else it }
            ).joinToString(" · ").ifBlank { "Følg ruten" },
            infoTitle = trip.name,
            infoLine = remainingInfoLine(),
            currentPoint = location?.let { CarPoint(it.longitude, it.latitude) },
            headingDegrees = heading,
            poiLabel = if (currentPoiBanner != null) "POI nærmer seg" else null,
            poiValue = currentPoiBanner,
            etaText = estimatedArrivalText(),
            remainingText = remainingDistanceText(),
            recording = false,
        )
    }

    private fun resolveDarkMode(): Boolean {
        return when (repo.readState().themeMode) {
            "light" -> false
            "dark" -> true
            else -> (carContext.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        }
    }

    private fun stopNavigation() {
        runCatching { navigationManager.navigationEnded() }
        repo.setSelectedTripId(null)
        screenManager.pop()
    }

    private fun maybeAnnounceManeuver() {
        val maneuver = currentManeuver ?: return
        val remaining = maneuver.distanceFromStartMeters - progressMeters
        for (threshold in listOf(650, 220, 55)) {
            val key = "${maneuver.id}:$threshold"
            if (remaining in 0.0..threshold.toDouble() && announced.add(key)) {
                speak("Om ${spokenDistance(remaining.roundToInt())}, ${maneuver.instruction}.")
                break
            }
        }
    }

    private fun speak(text: String) {
        if (!state.voiceEnabled || text.isBlank()) return
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "govia-car-${System.nanoTime()}")
    }

    private fun poiThreshold(category: String): Int = when (category.lowercase()) {
        "drivstoff" -> 1500
        "ferge" -> 2000
        "fare", "advarsel" -> 1800
        else -> 800
    }

    private fun displayDistance(meters: Double): Distance = if (meters >= 1000) {
        Distance.create(meters / 1000.0, Distance.UNIT_KILOMETERS_P1)
    } else {
        Distance.create(max(0.0, meters), Distance.UNIT_METERS)
    }

    private fun formatDistance(meters: Int): String = if (meters >= 1000) String.format(Locale("nb", "NO"), "%.1f km", meters / 1000.0) else "$meters m"
    private fun spokenDistance(meters: Int): String = if (meters >= 1000) String.format(Locale("nb", "NO"), "%.1f kilometer", meters / 1000.0) else "$meters meter"

    private fun remainingDistanceMeters(): Double = max(0.0, cumulative.lastOrNull()?.minus(progressMeters) ?: 0.0)

    private fun remainingDistanceText(): String = formatDistance(remainingDistanceMeters().roundToInt())

    private fun estimatedArrivalText(): String {
        val remainingSeconds = max(0.0, trip.totalDurationSeconds.toDouble() * (remainingDistanceMeters() / max(1.0, trip.totalDistanceMeters.toDouble())))
        val eta = System.currentTimeMillis() + (remainingSeconds * 1000.0).roundToInt()
        val calendar = java.util.Calendar.getInstance().apply { timeInMillis = eta }
        return String.format(Locale("nb", "NO"), "%02d:%02d", calendar.get(java.util.Calendar.HOUR_OF_DAY), calendar.get(java.util.Calendar.MINUTE))
    }

    private fun remainingInfoLine(): String {
        val distance = remainingDistanceText()
        val eta = estimatedArrivalText()
        return "$distance igjen · Ankomst $eta"
    }

    private fun nearestProgress(lat: Double, lon: Double): Double {
        if (geometry.isEmpty()) return 0.0
        var best = Double.MAX_VALUE
        var index = 0
        geometry.forEachIndexed { i, point ->
            val d = haversine(lat, lon, point.lat, point.lon)
            if (d < best) {
                best = d
                index = i
            }
        }
        return cumulative.getOrElse(index) { 0.0 }
    }

    private fun cumulativeDistances(points: List<CarPoint>): List<Double> {
        if (points.isEmpty()) return emptyList()
        val out = MutableList(points.size) { 0.0 }
        for (i in 1 until points.size) out[i] = out[i - 1] + haversine(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon)
        return out
    }

    private fun buildManeuvers(stages: List<CarStage>): List<OverallManeuver> {
        var offset = 0.0
        val out = mutableListOf<OverallManeuver>()
        stages.forEach { stage ->
            stage.maneuvers.forEach { maneuver -> out += OverallManeuver(maneuver.id, maneuver.instruction, maneuver.roadName, offset + maneuver.distanceFromStartMeters) }
            offset += stage.distanceMeters
        }
        return out.sortedBy { it.distanceFromStartMeters }
    }

    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371000.0
        val p1 = Math.toRadians(lat1); val p2 = Math.toRadians(lat2)
        val dp = Math.toRadians(lat2 - lat1); val dl = Math.toRadians(lon2 - lon1)
        val a = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    private data class OverallManeuver(val id: String, val instruction: String, val roadName: String, val distanceFromStartMeters: Double)

    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit
    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
}
