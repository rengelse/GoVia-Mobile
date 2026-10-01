package no.govia.mobile.car

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/** Product/runtime guardrails around the authoritative Ferrostar navigation engine. */
object NavigationHardening {
    fun selectStage(trip: CarTrip, preferredStageId: String?): CarStage? =
        trip.stages.firstOrNull { it.id == preferredStageId }
            ?: trip.stages.firstOrNull { it.status == "active" }
            ?: trip.stages.singleOrNull()
            ?: trip.stages.firstOrNull()

    fun shouldRunForegroundNavigation(
        navigating: Boolean,
        explicitNavigationStart: Boolean,
        hasPersistedNavigation: Boolean,
    ): Boolean = navigating || explicitNavigationStart || hasPersistedNavigation

    fun isSameActiveSession(
        activeTripId: String?,
        activeStageId: String?,
        navigating: Boolean,
        requestedTripId: String,
        requestedStageId: String,
    ): Boolean = navigating && activeTripId == requestedTripId && activeStageId == requestedStageId

    fun canApplyReroute(
        activeTripId: String?,
        activeStageId: String?,
        activeRouteId: String?,
        activeRevision: Int,
        requestedTripId: String,
        requestedStageId: String,
        requestedRouteId: String,
        requestedRevision: Int,
    ): Boolean =
        activeTripId == requestedTripId &&
            activeStageId == requestedStageId &&
            activeRouteId == requestedRouteId &&
            activeRevision == requestedRevision

    fun reroutedStage(
        source: CarStage,
        routeId: String,
        geometry: List<CarPoint>,
        maneuvers: List<CarManeuver>,
        speedLimitSections: List<CarSpeedLimitSection> = emptyList(),
        distanceMeters: Int,
        durationSeconds: Int,
    ): CarStage {
        val reprojectedWaypoints = source.waypoints.map { waypoint ->
            val location = waypoint.location ?: return@map waypoint
            waypoint.copy(
                distanceFromStartMeters = waypointProgress(
                    point = location,
                    geometry = geometry,
                    expectedProgressMeters = waypoint.distanceFromStartMeters.toDouble(),
                ).roundToInt(),
            )
        }
        return source.copy(
            id = source.id,
            routeId = routeId,
            waypoints = reprojectedWaypoints,
            geometry = geometry,
            maneuvers = maneuvers,
            speedLimitSections = speedLimitSections,
            distanceMeters = distanceMeters,
            durationSeconds = durationSeconds,
        )
    }

    /** Used only for POI/waypoint metadata; never for vehicle route matching or maneuver ownership. */
    private fun waypointProgress(
        point: CarPoint,
        geometry: List<CarPoint>,
        expectedProgressMeters: Double?,
    ): Double {
        if (geometry.size < 2) return 0.0
        val cumulative = MutableList(geometry.size) { 0.0 }
        for (i in 1 until geometry.size) {
            cumulative[i] = cumulative[i - 1] + haversine(geometry[i - 1], geometry[i])
        }
        var bestScore = Double.POSITIVE_INFINITY
        var bestProgress = 0.0
        val target = expectedProgressMeters?.takeIf { it > 0.0 }
        for (i in 0 until geometry.lastIndex) {
            val projection = project(point, geometry[i], geometry[i + 1])
            val progress = cumulative[i] + projection.segmentMeters * projection.t
            val targetPenalty = target?.let { min(250.0, kotlin.math.abs(progress - it) * 0.05) } ?: 0.0
            val score = projection.distanceMeters + targetPenalty
            if (score < bestScore) {
                bestScore = score
                bestProgress = progress
            }
        }
        return max(0.0, bestProgress)
    }

    private data class Projection(val t: Double, val distanceMeters: Double, val segmentMeters: Double)

    private fun project(point: CarPoint, a: CarPoint, b: CarPoint): Projection {
        val scale = cos(Math.toRadians(point.lat)).coerceIn(0.2, 1.0)
        val ax = a.lon * scale
        val ay = a.lat
        val bx = b.lon * scale
        val by = b.lat
        val px = point.lon * scale
        val py = point.lat
        val dx = bx - ax
        val dy = by - ay
        val length2 = dx * dx + dy * dy
        val t = if (length2 <= 1e-14) 0.0 else (((px - ax) * dx + (py - ay) * dy) / length2).coerceIn(0.0, 1.0)
        val snapped = CarPoint(lon = a.lon + (b.lon - a.lon) * t, lat = a.lat + (b.lat - a.lat) * t)
        return Projection(t, haversine(point, snapped), haversine(a, b))
    }

    private fun haversine(a: CarPoint, b: CarPoint): Double {
        val r = 6_371_000.0
        val p1 = Math.toRadians(a.lat)
        val p2 = Math.toRadians(b.lat)
        val dp = Math.toRadians(b.lat - a.lat)
        val dl = Math.toRadians(b.lon - a.lon)
        val x = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * r * atan2(sqrt(x), sqrt(1 - x))
    }
}
