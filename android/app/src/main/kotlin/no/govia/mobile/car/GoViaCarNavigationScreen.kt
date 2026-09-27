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
import androidx.car.app.model.Alert
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarText
import androidx.car.app.model.DateTimeWithZone
import androidx.car.app.model.Distance
import androidx.car.app.model.Template
import androidx.car.app.navigation.NavigationManager
import androidx.car.app.navigation.NavigationManagerCallback
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import no.govia.mobile.R
import java.util.Locale
import java.util.TimeZone
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

class GoViaCarNavigationScreen(
    carContext: CarContext,
    private val trip: CarTrip,
) : Screen(carContext), LocationListener, DefaultLifecycleObserver, TextToSpeech.OnInitListener {

    private val repo = GoViaCarRepository(carContext)
    private val initialState = repo.readState()
    private val locationManager = carContext.getSystemService(LocationManager::class.java)
    private val appManager = carContext.getCarService(AppManager::class.java)
    private val navigationManager = carContext.getCarService(NavigationManager::class.java)
    private val geometry = trip.stages.flatMap { it.geometry }
    private val cumulative = cumulativeDistances(geometry)
    private val maneuvers = buildManeuvers(trip.stages)
    private val mapSurface = GoViaCarMapSurface(carContext, geometry)

    private var tts: TextToSpeech? = null
    private var currentLocation: Location? = null
    private var progressMeters = 0.0
    private var currentManeuver: OverallManeuver? = null
    private val announced = mutableSetOf<String>()
    private var announcedPoiId: String? = null
    private var currentPoiBanner: String? = null
    private var voiceMuted = false

    init {
        lifecycle.addObserver(this)
        appManager.setSurfaceCallback(mapSurface)
        navigationManager.setNavigationManagerCallback(object : NavigationManagerCallback {
            override fun onStopNavigation() = stopNavigation()
        })
        navigationManager.navigationStarted()
        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.setControlCallbacks(
            GoViaCarMapSurface.ControlCallbacks(
                onSound = {
                    voiceMuted = !voiceMuted
                    if (voiceMuted) tts?.stop()
                    invalidate()
                },
                onZoomIn = { mapSurface.zoomBy(1.0) },
                onZoomOut = { mapSurface.zoomBy(-1.0) },
                onRecenter = { mapSurface.recenter() },
                onStop = { stopNavigation() },
            )
        )
        if (initialState.voiceEnabled) tts = TextToSpeech(carContext, this)
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
        runCatching { navigationManager.navigationEnded() }
        appManager.setSurfaceCallback(null)
        mapSurface.close()
        tts?.stop()
        tts?.shutdown()
        tts = null
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        val engine = tts ?: return
        val nb = engine.setLanguage(Locale.forLanguageTag("nb-NO"))
        if (nb < TextToSpeech.LANG_AVAILABLE) engine.setLanguage(Locale.forLanguageTag("no-NO"))
        speak("Navigasjon startet.")
    }

    override fun onLocationChanged(location: Location) {
        currentLocation = Location(location)
        progressMeters = nearestProgress(location.latitude, location.longitude)
        currentManeuver = maneuvers.firstOrNull { it.distanceFromStartMeters > progressMeters + 15.0 }

        val state = repo.readState()
        val poi = state.pois
            .filter { it.distanceMeters >= progressMeters }
            .minByOrNull { it.distanceMeters }
            ?.takeIf { it.distanceMeters - progressMeters <= poiThreshold(it.category) }
        currentPoiBanner = poi?.let { "${it.name} · ${formatDistance((it.distanceMeters - progressMeters).roundToInt())}" }

        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.updatePosition(location)
        maybeAnnounceManeuver()
        if (poi != null && announcedPoiId != poi.id) {
            announcedPoiId = poi.id
            val remainingPoi = (poi.distanceMeters - progressMeters).roundToInt()
            showPoiAlert(poi, remainingPoi)
            speak("Du nærmer deg ${poi.name}, om ${spokenDistance(remainingPoi)}.")
        }
        invalidate()
    }

    override fun onGetTemplate(): Template {
        val dark = resolveDarkMode()
        mapSurface.setDarkMode(dark)
        val maneuver = currentManeuver
        val distanceToTurn = maneuver?.let { max(0.0, it.distanceFromStartMeters - progressMeters) }
        val remaining = remainingDistanceMeters()
        val arrivalMillis = System.currentTimeMillis() + (estimatedRemainingSeconds() * 1000.0).toLong()

        mapSurface.updateNavigationOverlay(
            GoViaCarCockpitOverlayView.NavigationState(
                distance = distanceToTurn?.let { formatDistance(it.roundToInt()) }.orEmpty(),
                instruction = maneuver?.instruction?.let(::cleanNavigationText).orEmpty().ifBlank { "Følg ruten" },
                road = maneuver?.roadName?.let(::humanRoadName).orEmpty(),
                tripName = cleanTripName(trip.name),
                arrival = "Ankomst ${String.format(Locale("nb", "NO"), "%02d:%02d", java.util.Calendar.getInstance().apply { timeInMillis = arrivalMillis }.get(java.util.Calendar.HOUR_OF_DAY), java.util.Calendar.getInstance().apply { timeInMillis = arrivalMillis }.get(java.util.Calendar.MINUTE))}",
                remaining = "${formatDistance(remaining.roundToInt())} igjen",
                poi = currentPoiBanner,
                direction = overlayDirection(maneuver?.instruction.orEmpty()),
                voiceMuted = voiceMuted,
            )
        )

        val mapActions = ActionStrip.Builder()
            .addAction(Action.PAN)
            .addAction(iconAction(R.drawable.ic_car_recenter) { mapSurface.recenter() })
            .addAction(iconAction(R.drawable.ic_car_zoom_in) { mapSurface.zoomBy(1.0) })
            .addAction(iconAction(R.drawable.ic_car_zoom_out) { mapSurface.zoomBy(-1.0) })
            .build()

        val mainActions = ActionStrip.Builder()
            .addAction(
                Action.Builder()
                    .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, R.drawable.ic_car_sound)).build())
                    .setOnClickListener {
                        voiceMuted = !voiceMuted
                        if (voiceMuted) tts?.stop()
                        invalidate()
                    }
                    .build()
            )
            .addAction(
                Action.Builder()
                    .setTitle("Avslutt")
                    .setOnClickListener { stopNavigation() }
                    .build()
            )
            .build()

        // Guidance/status is rendered as a responsive GoVia overlay on the map surface.
        // We intentionally do not set Android Auto RoutingInfo here; that host card was the
        // oversized duplicate that obscured the map on 800x400 displays.
        return NavigationTemplate.Builder()
            .setActionStrip(mainActions)
            .setMapActionStrip(mapActions)
            .build()
    }

    private fun buildStep(maneuver: OverallManeuver?): Step {
        val cue = maneuver?.instruction?.let(::cleanNavigationText).orEmpty().ifBlank { "Følg ruten" }
        val road = maneuver?.roadName?.let(::humanRoadName)
        return Step.Builder()
            .setCue(cue)
            .apply { road?.let(::setRoad) }
            .setManeuver(Maneuver.Builder(maneuverType(cue)).build())
            .build()
    }

    private fun buildTravelEstimate(): TravelEstimate {
        val remaining = remainingDistanceMeters()
        val seconds = estimatedRemainingSeconds()
        val arrivalMillis = System.currentTimeMillis() + (seconds * 1000.0).toLong()
        val builder = TravelEstimate.Builder(
            displayDistance(remaining),
            DateTimeWithZone.create(arrivalMillis, TimeZone.getDefault()),
        )
        builder.setTripText(CarText.create(cleanTripName(trip.name).take(48)))
        return builder.build()
    }

    private fun showPoiAlert(poi: CarPoi, remainingMeters: Int) {
        if (carContext.carAppApiLevel < 5) return
        val alert = Alert.Builder(
            poi.id.hashCode(),
            CarText.create(poi.name.take(48)),
            10_000L,
        )
            .setSubtitle(CarText.create("POI nærmer seg · ${formatDistance(remainingMeters)}"))
            .build()
        runCatching { appManager.showAlert(alert) }
    }

    private fun iconAction(drawable: Int, action: () -> Unit): Action =
        Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build())
            .setOnClickListener(action)
            .build()


    private fun overlayDirection(cue: String): GoViaCarCockpitOverlayView.Direction {
        val value = cue.lowercase(Locale("nb", "NO"))
        return when {
            "u-sving" in value || "u-turn" in value -> GoViaCarCockpitOverlayView.Direction.UTURN
            "rundkjøring" in value || "roundabout" in value -> GoViaCarCockpitOverlayView.Direction.ROUNDABOUT
            "høyre" in value || "right" in value -> GoViaCarCockpitOverlayView.Direction.RIGHT
            "venstre" in value || "left" in value -> GoViaCarCockpitOverlayView.Direction.LEFT
            else -> GoViaCarCockpitOverlayView.Direction.STRAIGHT
        }
    }

    private fun maneuverType(cue: String): Int {
        val value = cue.lowercase(Locale("nb", "NO"))
        return when {
            "ferge" in value || "ferry" in value -> Maneuver.TYPE_FERRY_BOAT
            "u-sving" in value || "u-sving" in value || "u-turn" in value -> Maneuver.TYPE_U_TURN_LEFT
            "svakt til høyre" in value || "slight right" in value -> Maneuver.TYPE_TURN_SLIGHT_RIGHT
            "svakt til venstre" in value || "slight left" in value -> Maneuver.TYPE_TURN_SLIGHT_LEFT
            "høyre" in value || "right" in value -> Maneuver.TYPE_TURN_NORMAL_RIGHT
            "venstre" in value || "left" in value -> Maneuver.TYPE_TURN_NORMAL_LEFT
            "rundkjøring" in value || "roundabout" in value -> Maneuver.TYPE_ROUNDABOUT_ENTER_CCW
            "rett frem" in value || "fortsett" in value || "straight" in value || "følg ruten" in value -> Maneuver.TYPE_STRAIGHT
            else -> Maneuver.TYPE_STRAIGHT
        }
    }


    private fun cleanTripName(value: String): String {
        val trimmed = value.trim().replace(Regex("\\s+"), " ")
        if (trimmed.isBlank()) return "Aktiv tur"

        val arrow = when {
            "→" in trimmed -> "→"
            "->" in trimmed -> "->"
            else -> null
        }
        if (arrow != null) {
            val destination = trimmed.substringAfter(arrow).trim()
                .removeSuffix(", Norway")
                .removeSuffix(", Norge")
            if (destination.isNotBlank() && !looksLikeCoordinates(destination)) {
                return "Tur til ${destination.take(30)}"
            }
        }

        if (!looksLikeCoordinates(trimmed) && !trimmed.startsWith("Her ·", ignoreCase = true)) {
            return trimmed.take(38)
        }
        return "Aktiv tur"
    }

    private fun cleanNavigationText(value: String): String {
        val trimmed = value.trim()
        if (trimmed.isBlank()) return "Følg ruten"
        if (looksLikeCoordinates(trimmed)) return "Følg ruten"
        return trimmed
            .replace(Regex("\\s+"), " ")
            .take(90)
    }

    private fun humanRoadName(value: String): String? {
        val trimmed = value.trim()
        if (trimmed.isBlank() || looksLikeCoordinates(trimmed)) return null
        if (trimmed.startsWith("Her", ignoreCase = true)) return null
        return trimmed.replace(Regex("\\s+"), " ").take(48)
    }

    private fun looksLikeCoordinates(value: String): Boolean {
        if (Regex("-?\\d{1,3}\\.\\d{3,}\\s*[, ]\\s*-?\\d{1,3}\\.\\d{3,}").containsMatchIn(value)) return true
        val digits = value.count { it.isDigit() }
        val dots = value.count { it == '.' }
        return digits >= 8 && dots >= 2
    }

    private fun resolveDarkMode(): Boolean = when (repo.readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> (carContext.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }

    private fun stopNavigation() {
        runCatching { navigationManager.navigationEnded() }
        repo.setSelectedTripId(null)
        screenManager.popToRoot()
    }

    private fun maybeAnnounceManeuver() {
        val maneuver = currentManeuver ?: return
        val remaining = maneuver.distanceFromStartMeters - progressMeters
        for (threshold in listOf(650, 220, 55)) {
            val key = "${maneuver.id}:$threshold"
            if (remaining in 0.0..threshold.toDouble() && announced.add(key)) {
                speak("Om ${spokenDistance(remaining.roundToInt())}, ${cleanNavigationText(maneuver.instruction)}.")
                break
            }
        }
    }

    private fun speak(text: String) {
        if (!initialState.voiceEnabled || voiceMuted || text.isBlank()) return
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

    private fun formatDistance(meters: Int): String = if (meters >= 1000) {
        String.format(Locale("nb", "NO"), "%.1f km", meters / 1000.0)
    } else "$meters m"

    private fun spokenDistance(meters: Int): String = if (meters >= 1000) {
        String.format(Locale("nb", "NO"), "%.1f kilometer", meters / 1000.0)
    } else "$meters meter"

    private fun remainingDistanceMeters(): Double = max(0.0, cumulative.lastOrNull()?.minus(progressMeters) ?: trip.totalDistanceMeters.toDouble())

    private fun estimatedRemainingSeconds(): Double {
        val totalDistance = max(1.0, trip.totalDistanceMeters.toDouble())
        return max(0.0, trip.totalDurationSeconds.toDouble() * (remainingDistanceMeters() / totalDistance))
    }

    private fun nextManeuver(after: OverallManeuver?): OverallManeuver? {
        val currentDistance = after?.distanceFromStartMeters ?: progressMeters
        return maneuvers.firstOrNull { it.distanceFromStartMeters > currentDistance + 5.0 }
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
        for (i in 1 until points.size) {
            out[i] = out[i - 1] + haversine(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon)
        }
        return out
    }

    private fun buildManeuvers(stages: List<CarStage>): List<OverallManeuver> {
        var offset = 0.0
        val out = mutableListOf<OverallManeuver>()
        stages.forEach { stage ->
            stage.maneuvers.forEach { maneuver ->
                out += OverallManeuver(
                    maneuver.id,
                    maneuver.instruction,
                    maneuver.roadName,
                    offset + maneuver.distanceFromStartMeters,
                )
            }
            offset += stage.distanceMeters
        }
        return out.sortedBy { it.distanceFromStartMeters }
    }

    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371000.0
        val p1 = Math.toRadians(lat1)
        val p2 = Math.toRadians(lat2)
        val dp = Math.toRadians(lat2 - lat1)
        val dl = Math.toRadians(lon2 - lon1)
        val a = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    private data class OverallManeuver(
        val id: String,
        val instruction: String,
        val roadName: String,
        val distanceFromStartMeters: Double,
    )

    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit
    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
}
