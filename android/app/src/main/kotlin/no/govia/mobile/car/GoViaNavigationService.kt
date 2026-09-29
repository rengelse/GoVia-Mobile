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
        val speedLimitKph: Int?,
        val poiBanner: String?,
        val voiceMuted: Boolean,
        val routeGeometry: List<CarPoint>,
        val routeRevision: Int,
        val rerouting: Boolean,
        val arrived: Boolean,
        val offRouteState: CarOffRouteState,
        val gpsQuality: CarGpsQuality,
    )

    interface Listener {
        fun onNavigationStateChanged(state: State)
    }

    inner class LocalBinder : Binder() {
        val service: GoViaNavigationService get() = this@GoViaNavigationService
    }

    companion object {
        const val ACTION_NAVIGATION_ACTIVE = "no.govia.mobile.car.NAVIGATION_ACTIVE"
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
    private var activeStage: CarStage? = null
    private var core: NavigationCoreV2? = null
    private var geometry: List<CarPoint> = emptyList()
    private var cumulative: List<Double> = emptyList()
    private var progressMeters = 0.0
    private var currentLocation: Location? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var voiceMuted = false
    private val announced = mutableSetOf<String>()
    private var announcedPoiId: String? = null
    private var autoDriveDistanceMeters = 0.0
    private var autoDriveRunnable: Runnable? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var lastRerouteAt = 0L
    private var routeRevision = 0
    private var lastSnapshotPersistAt = 0L
    private var arrivalAnnounced = false

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

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val navigating = currentState?.navigating == true
        val explicitStart = intent?.action == ACTION_NAVIGATION_ACTIVE
        val persisted = if (!navigating && !explicitStart) GoViaCarRepository(this).persistedNavigationSession() else null
        if (!NavigationHardening.shouldRunForegroundNavigation(navigating, explicitStart, persisted != null)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (!navigating) {
            startForeground(
                NOTIFICATION_ID,
                buildNavigationNotification("GoVia navigasjon", "Starter navigasjon…"),
            )
            if (!explicitStart && persisted != null) {
                mainHandler.post { restorePersistedNavigation() }
            }
        }
        return START_STICKY
    }

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
        currentState?.takeIf { it.navigating }?.let { state ->
            runCatching { manager.navigationStarted() }
            updateNavigationManagerTrip(state)
        }
        currentState?.let(listener::onNavigationStateChanged)
    }

    fun detachCarContext() {
        listener = null
        runCatching { navigationManager?.clearNavigationManagerCallback() }
        navigationManager = null
        carContext = null
    }

    fun startNavigation(nextTrip: CarTrip, recovered: CarPersistedNavigationSession? = null) {
        val repository = GoViaCarRepository(this)
        voiceMuted = !repository.readState().voiceEnabled
        val preferredStageId = recovered?.stage?.id ?: repository.activeStageId()
        val selectedStage = recovered?.stage
            ?: NavigationHardening.selectStage(nextTrip, preferredStageId)
            ?: return
        val stage = ensureGuidanceStage(selectedStage)

        if (recovered == null && NavigationHardening.isSameActiveSession(
                activeTripId = trip?.id,
                activeStageId = activeStage?.id,
                navigating = currentState?.navigating == true,
                requestedTripId = nextTrip.id,
                requestedStageId = stage.id,
            )) {
            currentState?.let { state -> listener?.onNavigationStateChanged(state) }
            return
        }

        activeStage = stage
        trip = nextTrip.copy(stages = listOf(stage), end = stage.end)
        geometry = stage.geometry
        cumulative = cumulativeDistances(geometry)
        progressMeters = recovered?.snapshot?.progressMeters ?: 0.0
        core = NavigationCoreV2(CarNavigationRoute.fromStage(stage)).also { engine ->
            recovered?.snapshot?.let(engine::restore)
        }
        announced.clear()
        if (recovered != null) announced.addAll(recovered.guidanceKeys)
        announcedPoiId = null
        stopAutoDriveSimulation()
        autoDriveDistanceMeters = 0.0
        routeRevision += 1
        arrivalAnnounced = false

        startForeground(
            NOTIFICATION_ID,
            buildNavigationNotification(
                title = "GoVia navigerer",
                text = cleanTripName(stage.end.ifBlank { nextTrip.name }),
            ),
        )
        navigationManager?.navigationStarted()
        repository.persistNavigationRoute(nextTrip.id, stage, core!!.snapshot(), announced)
        lastSnapshotPersistAt = System.currentTimeMillis()
        if (tts == null) {
            ttsReady = false
            tts = TextToSpeech(this, this)
        }
        requestAudioFocus()
        if (isDeveloperAutoDriveTrip(nextTrip)) {
            // DEV simulator trips must be deterministic in DHU: do not mix real phone GPS
            // with the simulated route. Start the internal AutoDrive stream immediately.
            emitState()
            mainHandler.post { startAutoDriveSimulation() }
        } else {
            requestLocationUpdates()
            lastKnownLocation()?.let(::onLocationChanged) ?: emitState()
        }
    }

    fun stopNavigation() {
        stopAutoDriveSimulation()
        mainHandler.removeCallbacksAndMessages(null)
        runCatching { locationManager.removeUpdates(this) }
        runCatching { navigationManager?.navigationEnded() }
        GoViaCarRepository(this).clearNavigationSession()
        trip = null
        activeStage = null
        core = null
        geometry = emptyList()
        cumulative = emptyList()
        currentLocation = null
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
            speedLimitKph = null,
            poiBanner = null,
            voiceMuted = voiceMuted,
            routeGeometry = emptyList(),
            routeRevision = routeRevision,
            rerouting = false,
            arrived = false,
            offRouteState = CarOffRouteState.ON_ROUTE,
            gpsQuality = CarGpsQuality.UNKNOWN,
        )
        listener?.onNavigationStateChanged(currentState!!)
        tts?.stop()
        abandonAudioFocus()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    fun toggleVoiceMuted(): Boolean {
        voiceMuted = !voiceMuted
        if (voiceMuted) tts?.stop()
        emitState()
        return voiceMuted
    }

    override fun onLocationChanged(location: Location) {
        val engine = core ?: return
        if (geometry.isEmpty()) return
        currentLocation = Location(location)
        val session = engine.update(
            CarNavigationFix(
                lat = location.latitude,
                lon = location.longitude,
                speedMetersPerSecond = location.speed.toDouble().coerceIn(0.0, 80.0),
                headingDegrees = if (location.hasBearing()) location.bearing.toDouble() else 0.0,
                accuracyMeters = if (location.hasAccuracy()) location.accuracy.toDouble() else 999.0,
                timestampMillis = location.time.takeIf { it > 0L } ?: System.currentTimeMillis(),
            ),
        )
        progressMeters = session.progressMeters
        val justArrived = session.arrived && !arrivalAnnounced
        persistNavigationSnapshot(force = justArrived)
        maybeAnnounceManeuver(session)
        if (justArrived) {
            arrivalAnnounced = true
            speak("Du er fremme.")
        }
        maybeReroute(location)
        emitState()
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        val engine = tts ?: return
        val nb = engine.setLanguage(Locale.forLanguageTag("nb-NO"))
        if (nb < TextToSpeech.LANG_AVAILABLE) engine.setLanguage(Locale.forLanguageTag("no-NO"))
        ttsReady = true
        core?.state?.let(::maybeAnnounceManeuver)
    }

    override fun onDestroy() {
        stopAutoDriveSimulation()
        mainHandler.removeCallbacksAndMessages(null)
        runCatching { locationManager.removeUpdates(this) }
        runCatching { navigationManager?.navigationEnded() }
        tts?.stop()
        tts?.shutdown()
        ttsReady = false
        abandonAudioFocus()
        super.onDestroy()
    }

    private fun emitState() {
        val activeTrip = trip ?: return
        val session = core?.state
        val maneuver = session?.currentManeuver
        val distanceToStep = session?.distanceToManeuverMeters ?: 0.0
        val remaining = session?.remainingMeters ?: geometryDistanceFallback()
        val remainingSeconds = session?.remainingSeconds ?: activeStage?.durationSeconds?.toLong() ?: 0L
        val arrivalMillis = System.currentTimeMillis() + remainingSeconds * 1000L
        val currentStep = maneuver?.let(::buildStep)
        val nextStep = session?.nextManeuver?.let(::buildStep)
        val destinationEstimate = TravelEstimate.Builder(
            displayDistance(remaining),
            DateTimeWithZone.create(arrivalMillis, TimeZone.getDefault()),
        ).setRemainingTimeSeconds(remainingSeconds).build()
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
            currentRoad = maneuver?.let { humanRoadName(NavigationGuidanceV1.roadLabel(it)) },
            speedLimitKph = currentSpeedLimitKph(activeStage?.speedLimitSections.orEmpty(), progressMeters),
            poiBanner = poi,
            voiceMuted = voiceMuted,
            routeGeometry = geometry,
            routeRevision = routeRevision,
            rerouting = session?.rerouting == true,
            arrived = session?.arrived == true,
            offRouteState = session?.offRouteState ?: CarOffRouteState.ON_ROUTE,
            gpsQuality = session?.gpsQuality ?: CarGpsQuality.UNKNOWN,
        )
        currentState = state
        updateNavigationManagerTrip(state)
        updateTurnByTurnNotification(state)
        listener?.onNavigationStateChanged(state)
    }

    private fun geometryDistanceFallback(): Double =
        max(0.0, cumulative.lastOrNull()?.minus(progressMeters) ?: activeStage?.distanceMeters?.toDouble() ?: 0.0)


    private fun updateTurnByTurnNotification(state: State) {
        val stepText = if (state.arrived) "Du er fremme" else state.currentStep?.cue?.toString()?.takeIf { it.isNotBlank() } ?: "Følg ruten"
        val distance = if (state.arrived) "0 m" else formatDistance(state.distanceToStepMeters.roundToInt())
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

        val activeStep = state.currentStep ?: Step.Builder(if (state.arrived) "Du er fremme" else "Følg ruten")
            .setManeuver(Maneuver.Builder(if (state.arrived) Maneuver.TYPE_DESTINATION else Maneuver.TYPE_STRAIGHT).build())
            .build()
        val activeStepDistance = if (state.currentStep != null) state.distanceToStepMeters else state.remainingMeters
        val stepSeconds = if (state.remainingMeters > 0) {
            (state.remainingSeconds * (activeStepDistance / state.remainingMeters)).toLong().coerceAtLeast(0L)
        } else 0L
        val stepArrival = System.currentTimeMillis() + stepSeconds * 1000L
        builder.addStep(
            activeStep,
            TravelEstimate.Builder(
                displayDistance(activeStepDistance),
                DateTimeWithZone.create(stepArrival, TimeZone.getDefault()),
            ).setRemainingTimeSeconds(stepSeconds).build(),
        )
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
        if (geometry.size < 2 || trip == null || autoDriveRunnable != null) return
        if (cumulative.size != geometry.size) cumulative = cumulativeDistances(geometry)
        val routeLength = cumulative.lastOrNull() ?: return
        if (routeLength <= 0.0) return

        autoDriveDistanceMeters = progressMeters.coerceIn(0.0, routeLength)
        val speedMps = 13.9
        val runnable = object : Runnable {
            override fun run() {
                if (trip == null || geometry.size < 2) {
                    stopAutoDriveSimulation()
                    return
                }
                val point = pointAtRouteDistance(autoDriveDistanceMeters) ?: run {
                    stopAutoDriveSimulation()
                    return
                }
                val lookAhead = pointAtRouteDistance((autoDriveDistanceMeters + 12.0).coerceAtMost(routeLength)) ?: point
                val location = Location("govia-autodrive").apply {
                    latitude = point.lat
                    longitude = point.lon
                    bearing = bearingBetween(point, lookAhead).toFloat()
                    speed = speedMps.toFloat()
                    accuracy = 8.0f
                    time = System.currentTimeMillis()
                }
                onLocationChanged(location)

                if (autoDriveDistanceMeters >= routeLength || currentState?.arrived == true) {
                    stopAutoDriveSimulation()
                    return
                }
                autoDriveDistanceMeters = (autoDriveDistanceMeters + speedMps).coerceAtMost(routeLength)
                mainHandler.postDelayed(this, 1000L)
            }
        }
        autoDriveRunnable = runnable
        mainHandler.post(runnable)
    }

    private fun stopAutoDriveSimulation() {
        autoDriveRunnable?.let(mainHandler::removeCallbacks)
        autoDriveRunnable = null
    }

    private fun isDeveloperAutoDriveTrip(value: CarTrip): Boolean = value.id.startsWith("dev-")

    private fun pointAtRouteDistance(distanceMeters: Double): CarPoint? {
        if (geometry.isEmpty()) return null
        if (geometry.size == 1 || cumulative.size != geometry.size) return geometry.first()
        val target = distanceMeters.coerceIn(0.0, cumulative.last())
        var hi = cumulative.binarySearch(target)
        if (hi >= 0) return geometry[hi]
        hi = (-hi - 1).coerceIn(1, geometry.lastIndex)
        val lo = hi - 1
        val segmentLength = cumulative[hi] - cumulative[lo]
        if (segmentLength <= 0.001) return geometry[hi]
        val t = ((target - cumulative[lo]) / segmentLength).coerceIn(0.0, 1.0)
        val a = geometry[lo]
        val b = geometry[hi]
        return CarPoint(
            lon = a.lon + (b.lon - a.lon) * t,
            lat = a.lat + (b.lat - a.lat) * t,
        )
    }

    private fun persistNavigationSnapshot(force: Boolean = false) {
        val activeTripId = trip?.id ?: return
        val stage = activeStage ?: return
        val engine = core ?: return
        val now = System.currentTimeMillis()
        if (!force && now - lastSnapshotPersistAt < 5_000L) return
        GoViaCarRepository(this).persistNavigationSnapshot(
            tripId = activeTripId,
            stageId = stage.id,
            routeId = engine.route.routeId,
            snapshot = engine.snapshot(),
            guidanceKeys = announced,
        )
        lastSnapshotPersistAt = now
    }

    private fun maybeReroute(location: Location) {
        val activeTrip = trip ?: return
        val engine = core ?: return
        val session = engine.state ?: return
        if (session.rerouting || !session.rerouteRequired) return
        val now = System.currentTimeMillis()
        if (now - lastRerouteAt < 25_000L) return
        val stage = activeStage ?: return
        if (stage.transport == "train" || stage.transport == "ferry") return
        val destination = geometry.lastOrNull() ?: return

        val requestedTripId = activeTrip.id
        val requestedStageId = stage.id
        val requestedRouteId = engine.route.routeId
        val requestedRevision = routeRevision

        engine.setRerouteState(CarRerouteState.REROUTING)
        lastRerouteAt = now
        persistNavigationSnapshot(force = true)
        emitState()
        val locationCopy = Location(location)
        thread(name = "govia-car-reroute", isDaemon = true) {
            val result = runCatching { requestReroute(activeTrip, stage, locationCopy, destination) }.getOrNull()
            mainHandler.post {
                val currentCore = core
                val canApply = NavigationHardening.canApplyReroute(
                    activeTripId = trip?.id,
                    activeStageId = activeStage?.id,
                    activeRouteId = currentCore?.route?.routeId,
                    activeRevision = routeRevision,
                    requestedTripId = requestedTripId,
                    requestedStageId = requestedStageId,
                    requestedRouteId = requestedRouteId,
                    requestedRevision = requestedRevision,
                )
                if (!canApply || currentCore == null) {
                    emitState()
                    return@post
                }
                if (result == null) {
                    currentCore.setRerouteState(CarRerouteState.FAILED)
                    persistNavigationSnapshot(force = true)
                    emitState()
                    return@post
                }

                val reroutedStage = ensureGuidanceStage(result)
                val reroutedRoute = CarNavigationRoute.fromStage(reroutedStage)
                currentCore.replaceRoute(reroutedRoute)
                activeStage = reroutedStage
                trip = activeTrip.copy(stages = listOf(reroutedStage), end = reroutedStage.end)
                geometry = reroutedStage.geometry
                cumulative = cumulativeDistances(geometry)
                progressMeters = 0.0
                announced.clear()
                announcedPoiId = null
                routeRevision += 1
                currentCore.setRerouteState(CarRerouteState.IDLE)
                GoViaCarRepository(this).persistNavigationRoute(activeTrip.id, reroutedStage, currentCore.snapshot())
                lastSnapshotPersistAt = System.currentTimeMillis()
                emitState()
            }
        }
    }

    private fun requestReroute(activeTrip: CarTrip, sourceStage: CarStage, location: Location, destination: CarPoint): CarStage {
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
                    type = row.optString("type", "turn"),
                    modifier = row.optString("modifier"),
                    instruction = row.optString("instruction", "Fortsett"),
                    roadName = row.optString("roadName"),
                    roadRef = row.optString("roadRef"),
                    distanceMeters = row.optInt("distanceMeters"),
                    durationSeconds = row.optInt("durationSeconds"),
                    distanceFromStartMeters = row.optInt("distanceFromStartMeters"),
                    exit = row.optInt("exit").takeIf { row.has("exit") && !row.isNull("exit") },
                    source = row.optString("source", "reroute"),
                    confidence = row.optDouble("confidence", 0.0),
                    location = if (loc != null && loc.length() >= 2) CarPoint(loc.optDouble(0), loc.optDouble(1)) else null,
                ))
            }
        }.sortedBy { it.sequence }
        val speedLimitSections = CarSpeedLimitParser.parse(data, reroutedGeometry)
        val stage = NavigationHardening.reroutedStage(
            source = sourceStage,
            routeId = "${sourceStage.id}-route-reroute-${System.currentTimeMillis()}",
            geometry = reroutedGeometry,
            maneuvers = reroutedManeuvers,
            speedLimitSections = speedLimitSections,
            distanceMeters = data.optDouble("distance", 0.0).roundToInt(),
            durationSeconds = data.optDouble("duration", 0.0).roundToInt(),
        )
        return stage
    }

    private fun currentSpeedLimitKph(sections: List<CarSpeedLimitSection>, progressMeters: Double): Int? {
        if (sections.isEmpty() || !progressMeters.isFinite()) return null
        val progress = progressMeters.coerceAtLeast(0.0)
        return sections.lastOrNull { section ->
            section.confidence >= 0.75 &&
                progress >= section.startDistanceMeters.toDouble() &&
                progress < section.endDistanceMeters.toDouble()
        }?.speedLimitKph
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

    private fun maybeAnnounceManeuver(session: CarNavigationSessionState) {
        if (!ttsReady) return
        val maneuver = session.currentManeuver ?: return
        val remaining = session.distanceToManeuverMeters ?: return
        val speed = currentLocation?.speed?.toDouble()?.coerceIn(0.0, 45.0) ?: 0.0
        val cue = NavigationGuidanceV1.cueFor(maneuver, remaining, speed) ?: return
        if (!announced.add(cue.dedupeKey)) return
        speak(cue.spokenText)
    }

    private fun speak(text: String, queueMode: Int = TextToSpeech.QUEUE_FLUSH) {
        if (voiceMuted || !ttsReady || text.isBlank()) return
        tts?.speak(text, queueMode, null, "govia-car-${System.nanoTime()}")
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

    private fun buildStep(maneuver: CarManeuver): Step {
        val cue = cleanNavigationText(NavigationGuidanceV1.primaryInstruction(maneuver))
        val road = humanRoadName(NavigationGuidanceV1.roadLabel(maneuver))
        return Step.Builder(cue)
            .apply { road?.let(::setRoad) }
            .setManeuver(Maneuver.Builder(maneuverType(maneuver)).build())
            .build()
    }

    private fun cumulativeDistances(points: List<CarPoint>): List<Double> {
        if (points.isEmpty()) return emptyList()
        val values = MutableList(points.size) { 0.0 }
        for (i in 1 until points.size) {
            values[i] = values[i - 1] + haversine(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon)
        }
        return values
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

    private fun maneuverType(maneuver: CarManeuver): Int {
        val type = NavigationGuidanceV1.semanticType(maneuver)
        val modifier = maneuver.modifier.lowercase(Locale.ROOT).replace('_', ' ').replace('-', ' ')
        return when {
            type.contains("ferry") -> Maneuver.TYPE_FERRY_BOAT
            type == "roundabout" -> Maneuver.TYPE_ROUNDABOUT_ENTER_CCW
            type.contains("uturn") || modifier.contains("uturn") || modifier.contains("u turn") -> if (modifier.contains("right")) Maneuver.TYPE_U_TURN_RIGHT else Maneuver.TYPE_U_TURN_LEFT
            modifier.contains("slight right") -> Maneuver.TYPE_TURN_SLIGHT_RIGHT
            modifier.contains("slight left") -> Maneuver.TYPE_TURN_SLIGHT_LEFT
            modifier.contains("right") -> Maneuver.TYPE_TURN_NORMAL_RIGHT
            modifier.contains("left") -> Maneuver.TYPE_TURN_NORMAL_LEFT
            else -> Maneuver.TYPE_STRAIGHT
        }
    }

    private fun restorePersistedNavigation() {
        if (currentState?.navigating == true) return
        val repository = GoViaCarRepository(this)
        val persisted = repository.persistedNavigationSession() ?: run {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        val baseTrip = repository.readState().trips.firstOrNull { it.id == persisted.tripId }
            ?: CarTrip(
                id = persisted.tripId,
                name = persisted.stage.name.ifBlank { "Gjenopprettet tur" },
                start = persisted.stage.start,
                end = persisted.stage.end,
                status = "active",
                stages = listOf(persisted.stage),
            )
        startNavigation(baseTrip.copy(stages = listOf(persisted.stage), end = persisted.stage.end), persisted)
    }

    private fun ensureGuidanceStage(stage: CarStage): CarStage {
        if (stage.maneuvers.isNotEmpty() || stage.geometry.size < 2) return stage
        val distances = cumulativeDistances(stage.geometry)
        // Route curvature alone cannot distinguish a road bend from a decision point.
        // Keep emergency guidance non-directional rather than synthesizing false turns.
        val fallback = listOf(
            CarManeuver(
                id = "${stage.id}-fallback-start",
                sequence = 0,
                type = "continue",
                instruction = "Følg ruten",
                roadName = "",
                distanceMeters = 0,
                distanceFromStartMeters = minOf(40.0, distances.lastOrNull() ?: 40.0).roundToInt(),
                source = "geometry-emergency",
                confidence = 0.25,
                location = stage.geometry.firstOrNull(),
            ),
        )
        return stage.copy(maneuvers = fallback)
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
