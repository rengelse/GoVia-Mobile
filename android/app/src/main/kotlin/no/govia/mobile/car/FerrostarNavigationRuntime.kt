package no.govia.mobile.car

import com.stadiamaps.ferrostar.core.FerrostarSessionBuilder
import java.time.Instant
import kotlin.math.max
import uniffi.ferrostar.CourseFiltering
import uniffi.ferrostar.CourseOverGround
import uniffi.ferrostar.NavigationControllerConfig
import uniffi.ferrostar.NavState
import uniffi.ferrostar.RouteDeviationTracking
import uniffi.ferrostar.Speed
import uniffi.ferrostar.TripState
import uniffi.ferrostar.UserLocation
import uniffi.ferrostar.WaypointAdvanceMode
import uniffi.ferrostar.stepAdvanceDistanceEntryAndExit
import uniffi.ferrostar.stepAdvanceDistanceToEndOfStep

/**
 * The single authoritative navigation runtime used by both phone and Android Auto.
 *
 * Ferrostar owns route matching, snapped position, progress, step advancement, arrival and
 * deviation state. GoVia owns provider routing, reroute I/O, product state and presentation.
 */
class FerrostarNavigationRuntime(initialStage: CarStage) {
    data class State(
        val stageId: String,
        val routeId: String,
        val navigating: Boolean,
        val arrived: Boolean,
        val currentFix: CarNavigationFix?,
        val rawLocation: CarPoint?,
        val snappedLocation: CarPoint?,
        val progressMeters: Double,
        val remainingMeters: Double,
        val remainingSeconds: Long,
        val distanceToManeuverMeters: Double?,
        val currentManeuver: CarManeuver?,
        val nextManeuver: CarManeuver?,
        val currentRoad: String?,
        val speedLimitKph: Int?,
        val deviation: String,
        val rerouteRequired: Boolean,
        val offRouteState: CarOffRouteState,
        val spokenInstructionId: String?,
        val spokenInstructionText: String?,
        val gpsQuality: CarGpsQuality,
    )

    private var stage: CarStage = initialStage
    private var adapted = FerrostarRouteAdapter.convert(initialStage)
    private var session = FerrostarSessionBuilder(config()).build(adapted.route)
    private var navState: NavState? = null
    private var latest: State = idleState(initialStage)

    val state: State get() = latest
    val activeStage: CarStage get() = stage

    fun snapshot(): CarNavigationRuntimeSnapshot = CarNavigationRuntimeSnapshot(
        currentFix = latest.currentFix,
        progressMeters = latest.progressMeters,
        arrived = latest.arrived,
    )

    fun update(fix: CarNavigationFix): State {
        val location = UserLocation(
            coordinates = uniffi.ferrostar.GeographicCoordinate(lat = fix.lat, lng = fix.lon),
            horizontalAccuracy = fix.accuracyMeters.takeIf { it.isFinite() && it > 0 } ?: 999.0,
            courseOverGround = CourseOverGround(
                degrees = normalizeHeading(fix.headingDegrees).toUInt().toUShort(),
                accuracy = null,
            ),
            timestamp = Instant.ofEpochMilli(fix.timestampMillis),
            speed = Speed(
                value = fix.speedMetersPerSecond.takeIf { it.isFinite() }?.coerceIn(0.0, 80.0) ?: 0.0,
                accuracy = null,
            ),
        )
        val previous = navState
        val next = if (previous == null) {
            session.getInitialState(location)
        } else {
            session.updateUserLocation(location, previous)
        }
        navState = next
        latest = stateFrom(next, fix)
        return latest
    }

    /** Atomic reroute replacement. The old navigation controller is discarded completely. */
    fun replaceRoute(newStage: CarStage, fix: CarNavigationFix? = null): State {
        stage = newStage
        adapted = FerrostarRouteAdapter.convert(newStage)
        session = FerrostarSessionBuilder(config()).build(adapted.route)
        navState = null
        latest = idleState(newStage)
        return if (fix != null) update(fix) else latest
    }

    private fun stateFrom(nav: NavState, fix: CarNavigationFix): State {
        return when (val trip = nav.tripState) {
            is TripState.Navigating -> {
                val currentStep = trip.remainingSteps.firstOrNull()
                val nextStep = trip.remainingSteps.getOrNull(1)
                val current = currentStep?.let { stepToManeuver(it, 0) }
                val next = nextStep?.let { stepToManeuver(it, 1) }
                val remaining = trip.progress.distanceRemaining.coerceAtLeast(0.0)
                val progress = max(0.0, adapted.route.distance - remaining)
                val deviationText = trip.deviation.toString()
                State(
                    stageId = stage.id,
                    routeId = stage.routeId,
                    navigating = true,
                    arrived = false,
                    currentFix = fix,
                    rawLocation = CarPoint(fix.lon, fix.lat),
                    snappedLocation = CarPoint(
                        lon = trip.snappedUserLocation.coordinates.lng,
                        lat = trip.snappedUserLocation.coordinates.lat,
                    ),
                    progressMeters = progress,
                    remainingMeters = remaining,
                    remainingSeconds = trip.progress.durationRemaining.coerceAtLeast(0.0).toLong(),
                    distanceToManeuverMeters = trip.progress.distanceToNextManeuver.coerceAtLeast(0.0),
                    currentManeuver = current,
                    nextManeuver = next,
                    currentRoad = currentStep?.roadName,
                    speedLimitKph = speedLimitFromAnnotation(trip.annotationJson),
                    deviation = deviationText,
                    rerouteRequired = !deviationText.contains("NoDeviation", ignoreCase = true),
                    offRouteState = if (!deviationText.contains("NoDeviation", ignoreCase = true)) CarOffRouteState.OFF_ROUTE else CarOffRouteState.ON_ROUTE,
                    spokenInstructionId = trip.spokenInstruction?.utteranceId?.toString(),
                    spokenInstructionText = trip.spokenInstruction?.text,
                    gpsQuality = gpsQuality(fix.accuracyMeters),
                )
            }
            is TripState.Complete -> State(
                stageId = stage.id,
                routeId = stage.routeId,
                navigating = true,
                arrived = true,
                currentFix = fix,
                rawLocation = CarPoint(fix.lon, fix.lat),
                snappedLocation = CarPoint(
                    lon = trip.userLocation.coordinates.lng,
                    lat = trip.userLocation.coordinates.lat,
                ),
                progressMeters = adapted.route.distance,
                remainingMeters = 0.0,
                remainingSeconds = 0L,
                distanceToManeuverMeters = null,
                currentManeuver = null,
                nextManeuver = null,
                currentRoad = null,
                speedLimitKph = null,
                deviation = "complete",
                rerouteRequired = false,
                offRouteState = CarOffRouteState.ON_ROUTE,
                spokenInstructionId = null,
                spokenInstructionText = null,
                gpsQuality = gpsQuality(fix.accuracyMeters),
            )
            is TripState.Idle -> idleState(stage).copy(
                rawLocation = CarPoint(fix.lon, fix.lat),
                gpsQuality = gpsQuality(fix.accuracyMeters),
            )
        }
    }

    private fun stepToManeuver(step: uniffi.ferrostar.RouteStep, offset: Int): CarManeuver {
        val primary = step.visualInstructions.firstOrNull()?.primaryContent
        val type = primary?.maneuverType?.toString()?.lowercase()?.replace('-', '_') ?: "continue"
        val modifier = primary?.maneuverModifier?.toString()?.lowercase()?.replace('-', '_') ?: ""
        val exit = step.roundaboutExitNumber?.toInt()
            ?: step.exits.firstOrNull()?.toIntOrNull()
        return CarManeuver(
            id = "${stage.routeId}-runtime-${step.instruction.hashCode()}-$offset",
            sequence = offset,
            type = type,
            modifier = modifier,
            instruction = step.instruction,
            roadName = step.roadName.orEmpty(),
            roadRef = "",
            distanceMeters = step.distance.toInt(),
            durationSeconds = step.duration.toInt(),
            distanceFromStartMeters = latest.progressMeters.toInt(),
            exit = exit,
            source = "ferrostar",
            confidence = 1.0,
            location = null,
        )
    }

    private fun speedLimitFromAnnotation(annotation: String?): Int? = annotation
        ?.let { SPEED_LIMIT_REGEX.find(it)?.groupValues?.getOrNull(1)?.toIntOrNull() }
        ?.takeIf { it in 1..200 }

    private fun idleState(value: CarStage) = State(
        stageId = value.id,
        routeId = value.routeId,
        navigating = false,
        arrived = false,
        currentFix = null,
        rawLocation = null,
        snappedLocation = null,
        progressMeters = 0.0,
        remainingMeters = value.distanceMeters.toDouble(),
        remainingSeconds = value.durationSeconds.toLong(),
        distanceToManeuverMeters = null,
        currentManeuver = null,
        nextManeuver = null,
        currentRoad = null,
        speedLimitKph = null,
        deviation = "idle",
        rerouteRequired = false,
        offRouteState = CarOffRouteState.ON_ROUTE,
        spokenInstructionId = null,
        spokenInstructionText = null,
        gpsQuality = CarGpsQuality.UNKNOWN,
    )

    companion object {
        private val SPEED_LIMIT_REGEX = Regex("\\\"speedLimitKph\\\"\\s*:\\s*(\\d+)")

        fun config() = NavigationControllerConfig(
            WaypointAdvanceMode.WaypointWithinRange(80.0),
            stepAdvanceDistanceEntryAndExit(30u, 5u, 32u),
            stepAdvanceDistanceToEndOfStep(10u, 32u),
            RouteDeviationTracking.StaticThreshold(25u, 55.0),
            CourseFiltering.SNAP_TO_ROUTE,
        )

        private fun normalizeHeading(value: Double): Int {
            if (!value.isFinite()) return 0
            var result = value % 360.0
            if (result < 0) result += 360.0
            return result.toInt().coerceIn(0, 359)
        }

        fun gpsQuality(accuracyMeters: Double): CarGpsQuality = when {
            !accuracyMeters.isFinite() || accuracyMeters <= 0.0 -> CarGpsQuality.UNKNOWN
            accuracyMeters <= 25.0 -> CarGpsQuality.GOOD
            accuracyMeters <= 65.0 -> CarGpsQuality.DEGRADED
            else -> CarGpsQuality.POOR
        }
    }
}
