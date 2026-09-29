package no.govia.mobile.car

import kotlin.math.roundToInt

/** Pure navigation decisions kept outside Android framework code so they are behavior-testable. */
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
            val progress = NavigationCoreV2.routeProgressForPoint(
                point = location,
                geometry = geometry,
                expectedProgressMeters = waypoint.distanceFromStartMeters.toDouble(),
            )
            waypoint.copy(distanceFromStartMeters = progress.roundToInt())
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
}
