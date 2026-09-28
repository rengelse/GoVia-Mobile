package no.govia.mobile.car

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Binder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import androidx.car.app.CarContext
import androidx.car.app.model.DateTimeWithZone
import androidx.car.app.model.Distance
import androidx.car.app.navigation.NavigationManager
import androidx.car.app.navigation.NavigationManagerCallback
import androidx.car.app.navigation.model.Destination
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import androidx.car.app.navigation.model.Trip
import androidx.car.app.notification.CarAppExtender
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import no.govia.mobile.R
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.TimeZone
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.concurrent.thread

/**
 * Foreground navigation engine for Android Auto.
 *
 * This service owns location, route progress, voice guidance and NavigationManager metadata.
 * The car Screen is presentation only, matching the Android for Cars navigation architecture.
 */
class GoViaNavigationService : Service(), LocationListener, TextToSpeech.OnInitListener {

    data class State(
        val navigating: Boolean,
        val trip: CarTrip?,
        val location: Location?,
        val currentStep: Step?,
        val nextStep: Step?,
        val distanceToStepMeters: Double,
        val remainingMeters: Double,
        val remainingSeconds: Long,
        val arrivalMillis: Long,
        val destinationEstimate: TravelEstimate?,
        val currentRoad: String?,
        val poiBanner: String?,
        val voiceMuted: Boolean,
        val routeGeometry: List<CarPoint>,
        val routeRevision: Int,
        val rerouting: Boolean,
    )

    interface Listener {
        fun onNavigationStateChanged(state: State)
    }

    inner class LocalBinder : Binder() {
        val service: GoViaNavigationService get() = this@GoViaNavigationService
    }

    companion object {
        private const val CHANNEL_ID = "govia_navigation"
        private const val NOTIFICATION_ID = 42101
    }

    private val binder = LocalBinder()
    private lateinit var locationManager: LocationManager
    private lateinit var audioManager: AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var carContext: CarContext? = null
    private var navigationManager: NavigationManager? = null
    private var listener: Listener? = null
    private var trip: CarTrip? = null
    private var geometry: List<CarPoint> = emptyList()
    private var cumulative: List<Double> = emptyList()
    private var maneuvers: List<OverallManeuver> = emptyList()
    private var progressMeters = 0.0
    private var currentLocation: Location? = null
    private var currentManeuver: OverallManeuver? = null
    private var tts: TextToSpeech? = null
    private var voiceMuted = false
    private val announced = mutableSetOf<String>()
    private var announcedPoiId: String? = null
    private var autoDriveIndex = 0
    private var audioFocusRequest: AudioFocusRequest? = null
    private var offRouteFixes = 0
    private var lastRerouteAt = 0L
    private var rerouting = false
    private var routeRevision = 0
    private var navigationStartedAt = 0L
    private var firstProgressMeters = 0.0
    private var smoothedMovingSpeed: Double? = null

    @Volatile
    var currentState: State? = null
        private set

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(LocationManager::class.java)
        audioManager = getSystemService(AudioManager::class.java)
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

    fun attachCarContext(context: CarContext, listener: Listener) {
        carContext = context
        this.listener = listener
        val manager = context.getCarService(NavigationManager::class.java)
        navigationManager = manager
        manager.setNavigationManagerCallback(object : NavigationManagerCallback {
            override fun onStopNavigation() {
                stopNavigation()
            }

            override fun onAutoDriveEnabled() {
                startAutoDriveSimulation()
            }
        })
        currentState?.let(listener::onNavigationStateChanged)
    }

    fun detachCarContext() {
        listener = null
        runCatching { navigationManager?.clearNavigationManagerCallback() }
        navigationManager = null
        carContext = null
    }

    fun startNavigation(nextTrip: CarTrip) {
        val alreadyActive = trip?.id == nextTrip.id && currentState?.navigating == true
        trip = nextTrip
        geometry = nextTrip.stages.flatMap { it.geometry }
        cumulative = cumulativeDistances(geometry)
        maneuvers = buildManeuvers(nextTrip.stages)
        progressMeters = 0.0
        currentManeuver = maneuvers.firstOrNull()
        announced.clear()
        announcedPoiId = null
        autoDriveIndex = 0
        offRouteFixes = 0
        rerouting = false
        routeRevision += 1
        navigationStartedAt = System.currentTimeMillis()
        firstProgressMeters = 0.0
        smoothedMovingSpeed = null

        if (!alreadyActive) {
            startForeground(
                NOTIFICATION_ID,
                buildNavigationNotification(
                    title = "GoVia navigerer",
                    text = cleanTripName(nextTrip.name),
                ),
            )
            navigationManager?.navigationStarted()
            GoViaCarRepository(this).setSelectedTripId(nextTrip.id)
            if (tts == null) tts = TextToSpeech(this, this)
            requestAudioFocus()
            requestLocationUpdates()
        }

        lastKnownLocation()?.let(::onLocationChanged) ?: emitState()
    }

    fun stopNavigation() {
        mainHandler.removeCallbacksAndMessages(null)
        runCatching { locationManager.removeUpdates(this) }
        runCatching { navigationManager?.navigationEnded() }
        GoViaCarRepository(this).setSelectedTripId(null)
        trip = null
        geometry = emptyList()
        cumulative = emptyList()
        maneuvers = emptyList()
        currentLocation = null
        currentManeuver = null
        progressMeters = 0.0
        currentState = State(
            navigating = false,
            trip = null,
            location = null,
            currentStep = null,
            nextStep = null,
            distanceToStepMeters = 0.0,
            remainingMeters = 0.0,
            remainingSeconds = 0L,
            arrivalMillis = System.currentTimeMillis(),
            destinationEstimate = null,
            currentRoad = null,
            poiBanner = null,
            voiceMuted = voiceMuted,
            routeGeometry = emptyList(),
            routeRevision = routeRevision,
            rerouting = false,
        )
        listener?.onNavigationStateChanged(currentState!!)
        tts?.stop()
        abandonAudioFocus()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    fun toggleVoiceMuted(): Boolean {
        voiceMuted = !voiceMuted
        if (voiceMuted) tts?.stop()
        emitState()
        return voiceMuted
    }

    override fun onLocationChanged(location: Location) {
        if (trip == null || geometry.isEmpty()) return
        currentLocation = Location(location)
        val projection = nearestRouteProjection(location.latitude, location.longitude)
        if (projection.progressMeters >= progressMeters - 35.0) {
            progressMeters = max(progressMeters, projection.progressMeters)
        }
        if (firstProgressMeters == 0.0) firstProgressMeters = progressMeters
        val speed = location.speed.toDouble().coerceIn(0.0, 80.0)
        if (speed >= 1.5) {
            smoothedMovingSpeed = smoothedMovingSpeed?.let { it * 0.82 + speed * 0.18 } ?: speed
        }
        if (projection.distanceMeters > 85.0) offRouteFixes += 1 else offRouteFixes = 0
        currentManeuver = maneuvers.firstOrNull { it.distanceFromStartMeters > progressMeters + 15.0 }
        maybeAnnounceManeuver()
        maybeReroute(location)
        emitState()
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        val engine = tts ?: return
        val nb = engine.setLanguage(Locale.forLanguageTag("nb-NO"))
        if (nb < TextToSpeech.LANG_AVAILABLE) engine.setLanguage(Locale.forLanguageTag("no-NO"))
        speak("Navigasjon startet.")
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        runCatching { locationManager.removeUpdates(this) }
        runCatching { navigationManager?.navigationEnded() }
        tts?.stop()
        tts?.shutdown()
        abandonAudioFocus()
        super.onDestroy()
    }

    private fun emitState() {
        val activeTrip = trip ?: return
        val maneuver = currentManeuver
        val distanceToStep = maneuver?.let { max(0.0, it.distanceFromStartMeters - progressMeters) } ?: 0.0
        val remaining = remainingDistanceMeters(activeTrip)
        val remainingSeconds = estimatedRemainingSeconds(activeTrip, remaining)
        val arrivalMillis = System.currentTimeMillis() + remainingSeconds * 1000L
        val currentStep = maneuver?.let(::buildStep)
        val nextStep = nextManeuver(maneuver)?.let(::buildStep)
        val destinationEstimate = TravelEstimate.Builder(
            displayDistance(remaining),
            DateTimeWithZone.create(arrivalMillis, TimeZone.getDefault()),
        )
            .setRemainingTimeSeconds(remainingSeconds)
            .build()

        val poi = nextPoiBanner()
        val state = State(
            navigating = true,
            trip = activeTrip,
            location = currentLocation?.let(::Location),
            currentStep = currentStep,
            nextStep = nextStep,
            distanceToStepMeters = distanceToStep,
            remainingMeters = remaining,
            remainingSeconds = remainingSeconds,
            arrivalMillis = arrivalMillis,
            destinationEstimate = destinationEstimate,
            currentRoad = maneuver?.roadName?.let(::humanRoadName),
            poiBanner = poi,
            voiceMuted = voiceMuted,
            routeGeometry = geometry,
            routeRevision = routeRevision,
            rerouting = rerouting,
        )
        currentState = state
        updateNavigationManagerTrip(state)
        updateTurnByTurnNotification(state)
        listener?.onNavigationStateChanged(state)
    }


    private fun updateTurnByTurnNotification(state: State) {
        val stepText = state.currentStep?.cue?.toString()?.takeIf { it.isNotBlank() } ?: "Følg ruten"
        val distance = formatDistance(state.distanceToStepMeters.roundToInt())
        NotificationManagerCompat.from(this).notify(
            NOTIFICATION_ID,
            buildNavigationNotification(
                title = "$distance · $stepText",
                text = state.trip?.end?.takeIf { it.isNotBlank() } ?: "GoVia navigasjon",
            ),
        )
    }

    private fun buildNavigationNotification(title: String, text: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_car_active)
            .setContentTitle(title)
            .setContentText(text)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .extend(
                CarAppExtender.Builder()
                    .setContentTitle(title)
                    .setContentText(text)
                    .setSmallIcon(R.drawable.ic_car_active)
                    .setImportance(NotificationManagerCompat.IMPORTANCE_DEFAULT)
                    .build(),
            )
            .build()

    private fun updateNavigationManagerTrip(state: State) {
        val manager = navigationManager ?: return
        val activeTrip = state.trip ?: return
        val estimate = state.destinationEstimate ?: return
        val builder = Trip.Builder()
            .addDestination(
                Destination.Builder()
                    .setName(cleanTripName(activeTrip.end.ifBlank { activeTrip.name }))
                    .setAddress(activeTrip.end.take(80))
                    .build(),
                estimate,
            )
            .setLoading(false)

        state.currentStep?.let { step ->
            val stepSeconds = if (state.remainingMeters > 0) {
                (state.remainingSeconds * (state.distanceToStepMeters / state.remainingMeters)).toLong().coerceAtLeast(0L)
            } else 0L
            val stepArrival = System.currentTimeMillis() + stepSeconds * 1000L
            builder.addStep(
                step,
                TravelEstimate.Builder(
                    displayDistance(state.distanceToStepMeters),
                    DateTimeWithZone.create(stepArrival, TimeZone.getDefault()),
                ).setRemainingTimeSeconds(stepSeconds).build(),
            )
        }
        state.currentRoad?.let(builder::setCurrentRoad)
        runCatching { manager.updateTrip(builder.build()) }
    }

    private fun requestLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
        runCatching { locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 2f, this) }
        runCatching { locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 2500L, 8f, this) }
    }

    private fun lastKnownLocation(): Location? {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return null
        val gps = runCatching { locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull()
        val network = runCatching { locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull()
        return listOfNotNull(gps, network).maxByOrNull { it.time }
    }

    private fun startAutoDriveSimulation() {
        if (geometry.size < 2 || trip == null) return
        mainHandler.removeCallbacksAndMessages(null)
        autoDriveIndex = 0
        val runnable = object : Runnable {
            override fun run() {
                val point = geometry.getOrNull(autoDriveIndex) ?: return
                val next = geometry.getOrNull((autoDriveIndex + 1).coerceAtMost(geometry.lastIndex)) ?: point
                val location = Location("govia-autodrive").apply {
                    latitude = point.lat
                    longitude = point.lon
                    bearing = bearingBetween(point, next).toFloat()
                    speed = 13.9f
                    time = System.currentTimeMillis()
                }
                onLocationChanged(location)
                if (autoDriveIndex < geometry.lastIndex) {
                    autoDriveIndex++
                    mainHandler.postDelayed(this, 1000L)
                }
            }
        }
        mainHandler.post(runnable)
    }

    private fun maybeReroute(location: Location) {
        val activeTrip = trip ?: return
        if (rerouting || offRouteFixes < 3) return
        val now = System.currentTimeMillis()
        if (now - lastRerouteAt < 25_000L) return
        val stage = activeTrip.stages.lastOrNull { it.geometry.size >= 2 } ?: return
        if (stage.transport == "train" || stage.transport == "ferry") return
        val destination = geometry.lastOrNull() ?: return
        rerouting = true
        lastRerouteAt = now
        emitState()
        val locationCopy = Location(location)
        thread(name = "govia-car-reroute", isDaemon = true) {
            val result = runCatching { requestReroute(activeTrip, stage, locationCopy, destination) }.getOrNull()
            mainHandler.post {
                rerouting = false
                if (result != null && trip?.id == activeTrip.id) {
                    trip = result
                    geometry = result.stages.flatMap { it.geometry }
                    cumulative = cumulativeDistances(geometry)
                    maneuvers = buildManeuvers(result.stages)
                    progressMeters = 0.0
                    firstProgressMeters = 0.0
                    navigationStartedAt = System.currentTimeMillis()
                    smoothedMovingSpeed = null
                    currentManeuver = maneuvers.firstOrNull()
                    offRouteFixes = 0
                    announced.clear()
                    routeRevision += 1
                }
                emitState()
            }
        }
    }

    private fun requestReroute(activeTrip: CarTrip, sourceStage: CarStage, location: Location, destination: CarPoint): CarTrip {
        val points = JSONArray()
            .put(JSONObject().put("coord", JSONArray().put(location.longitude).put(location.latitude)).put("name", "Her"))
            .put(JSONObject().put("coord", JSONArray().put(destination.lon).put(destination.lat)).put("name", activeTrip.end))
        val preferences = sourceStage.routePreferences
        val body = JSONObject()
            .put("points", points)
            .put("mode", routeMode(sourceStage.transport))
            .put("profile", sourceStage.routeProfile)
            .put("preferences", JSONObject()
                .put("avoidMotorways", preferences.avoidMotorways)
                .put("avoidTolls", preferences.avoidTolls)
                .put("avoidFerries", preferences.avoidFerries)
                .put("avoidUnpaved", preferences.avoidUnpaved)
                .put("avoidCities", preferences.avoidCities)
                .put("preferScenic", preferences.preferScenic)
                .put("preferCoastal", preferences.preferCoastal)
                .put("preferMountains", preferences.preferMountains))
        val payload = runCatching { postRouteJson(body) }.getOrElse {
            postRouteJson(JSONObject()
                .put("points", points)
                .put("mode", routeMode(sourceStage.transport)))
        }
        val data = payload.optJSONObject("data") ?: error("Ugyldig rutesvar")
        val geometryJson = data.optJSONArray("geometry") ?: error("Ruten mangler geometri")
        val reroutedGeometry = buildList {
            for (i in 0 until geometryJson.length()) {
                val row = geometryJson.optJSONArray(i) ?: continue
                if (row.length() >= 2) add(CarPoint(row.optDouble(0), row.optDouble(1)))
            }
        }
        require(reroutedGeometry.size >= 2) { "Ruten mangler geometri" }
        val maneuversJson = data.optJSONArray("maneuvers") ?: JSONArray()
        val reroutedManeuvers = buildList {
            for (i in 0 until maneuversJson.length()) {
                val row = maneuversJson.optJSONObject(i) ?: continue
                val loc = row.optJSONArray("location")
                add(CarManeuver(
                    id = row.optString("id", "reroute-$i"),
                    sequence = row.optInt("sequence", i),
                    instruction = row.optString("instruction", "Fortsett"),
                    roadName = row.optString("roadName"),
                    distanceMeters = row.optInt("distanceMeters"),
                    distanceFromStartMeters = row.optInt("distanceFromStartMeters"),
                    location = if (loc != null && loc.length() >= 2) CarPoint(loc.optDouble(0), loc.optDouble(1)) else null,
                ))
            }
        }.sortedBy { it.sequence }
        val stage = CarStage(
            id = "${sourceStage.id}-reroute-${System.currentTimeMillis()}",
            day = sourceStage.day,
            order = sourceStage.order,
            start = "Her",
            end = activeTrip.end,
            transport = sourceStage.transport,
            distanceMeters = data.optDouble("distance", 0.0).roundToInt(),
            durationSeconds = data.optDouble("duration", 0.0).roundToInt(),
            geometry = reroutedGeometry,
            maneuvers = reroutedManeuvers,
            routeProfile = sourceStage.routeProfile,
            routePreferences = sourceStage.routePreferences,
        )
        return activeTrip.copy(stages = listOf(stage))
    }

    private fun postRouteJson(body: JSONObject): JSONObject {
        val state = GoViaCarRepository(this).readState()
        val baseUrl = state.apiBaseUrl.trimEnd('/').ifBlank { "https://govia.no" }
        val connection = (URL("$baseUrl/api/v1/map/route").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 10_000
            readTimeout = 15_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "GoVia-Mobile-AndroidAuto")
            setRequestProperty("x-govia-client", "mobile")
            state.accessToken?.takeIf { it.isNotBlank() }?.let { setRequestProperty("Authorization", "Bearer $it") }
        }
        return try {
            connection.outputStream.bufferedWriter(Charsets.UTF_8).use { it.write(body.toString()) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (code !in 200..299) error("HTTP $code: ${text.take(240)}")
            JSONObject(text)
        } finally {
            connection.disconnect()
        }
    }

    private fun routeMode(transport: String): String = when (transport.lowercase()) {
        "walking" -> "walking"
        "cycling" -> "cycling"
        "train" -> "rail"
        "ferry" -> "ferry"
        else -> "driving"
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
        if (voiceMuted || text.isBlank()) return
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "govia-car-${System.nanoTime()}")
    }

    private fun requestAudioFocus() {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener { }
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let(audioManager::abandonAudioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        audioFocusRequest = null
    }

    private fun nextPoiBanner(): String? {
        val activeStagePois = trip?.stages
            ?.flatMap { stage -> stage.waypoints.filter { it.kind == "poi" } }
            .orEmpty()
        val poiId: String
        val poiName: String
        val poiDistance: Int

        if (activeStagePois.isNotEmpty()) {
            val poi = activeStagePois
                .filter { it.distanceFromStartMeters >= progressMeters }
                .minByOrNull { it.distanceFromStartMeters }
                ?.takeIf { it.distanceFromStartMeters - progressMeters <= poiThreshold(it.category) }
                ?: return null
            poiId = poi.id
            poiName = poi.name
            poiDistance = poi.distanceFromStartMeters
        } else {
            val poi = GoViaCarRepository(this).readState().pois
                .filter { it.distanceMeters >= progressMeters }
                .minByOrNull { it.distanceMeters }
                ?.takeIf { it.distanceMeters - progressMeters <= poiThreshold(it.category) }
                ?: return null
            poiId = poi.id
            poiName = poi.name
            poiDistance = poi.distanceMeters
        }

        if (announcedPoiId != poiId) {
            announcedPoiId = poiId
            speak("Du nærmer deg $poiName, om ${spokenDistance((poiDistance - progressMeters).roundToInt())}.")
        }
        return "$poiName · ${formatDistance((poiDistance - progressMeters).roundToInt())}"
    }

    private fun buildStep(maneuver: OverallManeuver): Step {
        val cue = cleanNavigationText(maneuver.instruction)
        return Step.Builder(cue)
            .apply { humanRoadName(maneuver.roadName)?.let(::setRoad) }
            .setManeuver(Maneuver.Builder(maneuverType(cue)).build())
            .build()
    }

    private fun nextManeuver(after: OverallManeuver?): OverallManeuver? {
        val currentDistance = after?.distanceFromStartMeters ?: progressMeters
        return maneuvers.firstOrNull { it.distanceFromStartMeters > currentDistance + 5.0 }
    }

    private fun remainingDistanceMeters(activeTrip: CarTrip): Double =
        max(0.0, cumulative.lastOrNull()?.minus(progressMeters) ?: activeTrip.totalDistanceMeters.toDouble())

    private fun estimatedRemainingSeconds(activeTrip: CarTrip, remaining: Double): Long {
        if (remaining <= 0.0) return 0L
        val totalDistance = max(1.0, cumulative.lastOrNull() ?: activeTrip.totalDistanceMeters.toDouble())
        val baselineSeconds = max(1.0, activeTrip.totalDurationSeconds.toDouble())
        val baselineSpeed = totalDistance / baselineSeconds
        val elapsedSeconds = (System.currentTimeMillis() - navigationStartedAt).coerceAtLeast(0L) / 1000.0
        val progressed = max(0.0, progressMeters - firstProgressMeters)
        val observedSpeed = if (elapsedSeconds >= 90.0 && progressed >= 500.0) progressed / elapsedSeconds else null
        var effectiveSpeed = baselineSpeed
        if (observedSpeed != null && observedSpeed >= 1.5) effectiveSpeed = baselineSpeed * 0.45 + observedSpeed * 0.55
        smoothedMovingSpeed?.takeIf { it >= 1.5 }?.let { effectiveSpeed = effectiveSpeed * 0.75 + it * 0.25 }
        effectiveSpeed = effectiveSpeed.coerceIn(baselineSpeed * 0.45, baselineSpeed * 1.35)
        return (remaining / max(0.8, effectiveSpeed)).toLong().coerceAtLeast(0L)
    }

    private fun cumulativeDistances(points: List<CarPoint>): List<Double> {
        if (points.isEmpty()) return emptyList()
        val values = MutableList(points.size) { 0.0 }
        for (i in 1 until points.size) {
            values[i] = values[i - 1] + haversine(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon)
        }
        return values
    }

    private fun buildManeuvers(stages: List<CarStage>): List<OverallManeuver> {
        var stageOffset = 0.0
        val out = mutableListOf<OverallManeuver>()
        stages.sortedWith(compareBy<CarStage> { it.day }.thenBy { it.order }).forEach { stage ->
            val stageManeuvers = if (stage.maneuvers.isNotEmpty()) {
                stage.maneuvers.sortedBy { it.sequence }.map { maneuver ->
                    OverallManeuver(
                        id = maneuver.id,
                        instruction = maneuver.instruction,
                        roadName = maneuver.roadName,
                        distanceFromStartMeters = stageOffset + maneuver.distanceFromStartMeters,
                    )
                }
            } else {
                buildGeometryFallbackManeuvers(stage, stageOffset)
            }
            out += stageManeuvers
            stageOffset += max(stage.distanceMeters.toDouble(), cumulativeDistances(stage.geometry).lastOrNull() ?: 0.0)
        }
        return out.sortedBy { it.distanceFromStartMeters }
    }

    /**
     * Routes imported from older Desktop/mobile snapshots can contain geometry without
     * maneuver metadata. Android Auto must still enter guidance immediately instead of
     * leaving NavigationTemplate in an endless loading state.
     */
    private fun buildGeometryFallbackManeuvers(stage: CarStage, stageOffset: Double): List<OverallManeuver> {
        if (stage.geometry.size < 2) return emptyList()
        val distances = cumulativeDistances(stage.geometry)
        val result = mutableListOf(
            OverallManeuver(
                id = "${stage.id}-fallback-start",
                instruction = "Følg ruten",
                roadName = null,
                distanceFromStartMeters = stageOffset + minOf(40.0, distances.lastOrNull() ?: 40.0),
            )
        )
        var lastAdded = 0.0
        for (i in 1 until stage.geometry.lastIndex) {
            val here = distances.getOrNull(i) ?: continue
            if (here - lastAdded < 120.0) continue
            val incoming = bearingBetween(stage.geometry[i - 1], stage.geometry[i])
            val outgoing = bearingBetween(stage.geometry[i], stage.geometry[i + 1])
            val delta = signedTurnDelta(incoming, outgoing)
            if (kotlin.math.abs(delta) < 35.0) continue
            result += OverallManeuver(
                id = "${stage.id}-fallback-$i",
                instruction = if (delta > 0.0) "Sving til høyre" else "Sving til venstre",
                roadName = null,
                distanceFromStartMeters = stageOffset + here,
            )
            lastAdded = here
        }
        return result
    }

    private fun signedTurnDelta(fromBearing: Double, toBearing: Double): Double =
        ((toBearing - fromBearing + 540.0) % 360.0) - 180.0

    private data class RouteProjection(val progressMeters: Double, val distanceMeters: Double)

    private fun nearestRouteProjection(lat: Double, lon: Double): RouteProjection {
        if (geometry.size < 2 || cumulative.size != geometry.size) return RouteProjection(0.0, 0.0)
        var bestDistance = Double.MAX_VALUE
        var bestProgress = 0.0
        for (i in 0 until geometry.lastIndex) {
            val a = geometry[i]
            val b = geometry[i + 1]
            val projection = project(lat, lon, a.lat, a.lon, b.lat, b.lon)
            if (projection.distanceMeters < bestDistance) {
                bestDistance = projection.distanceMeters
                bestProgress = cumulative[i] + projection.segmentMeters * projection.t
            }
        }
        return RouteProjection(
            progressMeters = bestProgress.coerceIn(0.0, cumulative.lastOrNull() ?: 0.0),
            distanceMeters = bestDistance,
        )
    }

    private data class Projection(val t: Double, val distanceMeters: Double, val segmentMeters: Double)

    private fun project(lat: Double, lon: Double, aLat: Double, aLon: Double, bLat: Double, bLon: Double): Projection {
        val scale = cos(Math.toRadians(lat)).coerceAtLeast(0.2)
        val ax = aLon * scale
        val ay = aLat
        val bx = bLon * scale
        val by = bLat
        val px = lon * scale
        val py = lat
        val dx = bx - ax
        val dy = by - ay
        val length2 = dx * dx + dy * dy
        val t = if (length2 <= 1e-14) 0.0 else (((px - ax) * dx + (py - ay) * dy) / length2).coerceIn(0.0, 1.0)
        val qLat = aLat + (bLat - aLat) * t
        val qLon = aLon + (bLon - aLon) * t
        return Projection(t, haversine(lat, lon, qLat, qLon), haversine(aLat, aLon, bLat, bLon))
    }

    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6_371_000.0
        val p1 = Math.toRadians(lat1)
        val p2 = Math.toRadians(lat2)
        val dp = Math.toRadians(lat2 - lat1)
        val dl = Math.toRadians(lon2 - lon1)
        val a = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    private fun bearingBetween(from: CarPoint, to: CarPoint): Double {
        val lat1 = Math.toRadians(from.lat)
        val lat2 = Math.toRadians(to.lat)
        val dLon = Math.toRadians(to.lon - from.lon)
        val y = sin(dLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return ((Math.toDegrees(atan2(y, x)) % 360.0) + 360.0) % 360.0
    }

    private fun displayDistance(meters: Double): Distance = if (meters >= 1000.0) {
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

    private fun cleanNavigationText(value: String): String = value.trim()
        .replace(Regex("\\s+"), " ")
        .ifBlank { "Følg ruten" }
        .take(90)

    private fun humanRoadName(value: String?): String? = value?.trim()
        ?.replace(Regex("\\s+"), " ")
        ?.takeIf { it.isNotBlank() && !it.startsWith("Her", ignoreCase = true) }
        ?.take(48)

    private fun cleanTripName(value: String): String = value.trim()
        .replace(Regex("\\s+"), " ")
        .ifBlank { "GoVia-tur" }
        .take(48)

    private fun poiThreshold(category: String): Int = when (category.lowercase()) {
        "drivstoff" -> 1500
        "ferge" -> 2000
        "fare", "advarsel" -> 1800
        else -> 800
    }

    private fun maneuverType(cue: String): Int {
        val value = cue.lowercase(Locale("nb", "NO"))
        return when {
            "ferge" in value || "ferry" in value -> Maneuver.TYPE_FERRY_BOAT
            "u-sving" in value || "u-turn" in value -> Maneuver.TYPE_U_TURN_LEFT
            "svakt til høyre" in value || "slight right" in value -> Maneuver.TYPE_TURN_SLIGHT_RIGHT
            "svakt til venstre" in value || "slight left" in value -> Maneuver.TYPE_TURN_SLIGHT_LEFT
            "høyre" in value || "right" in value -> Maneuver.TYPE_TURN_NORMAL_RIGHT
            "venstre" in value || "left" in value -> Maneuver.TYPE_TURN_NORMAL_LEFT
            "rundkjøring" in value || "roundabout" in value -> Maneuver.TYPE_ROUNDABOUT_ENTER_CCW
            else -> Maneuver.TYPE_STRAIGHT
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "GoVia navigasjon", NotificationManager.IMPORTANCE_LOW),
        )
    }

    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit
    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
}

internal data class OverallManeuver(
    val id: String,
    val instruction: String,
    val roadName: String?,
    val distanceFromStartMeters: Double,
)
