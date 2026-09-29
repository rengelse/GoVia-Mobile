package no.govia.mobile.car

/** Pure navigation decisions kept outside Android framework code so they are behavior-testable. */
object NavigationHardening {
    fun selectStage(trip: CarTrip, preferredStageId: String?): CarStage? =
        trip.stages.firstOrNull { it.id == preferredStageId }
            ?: trip.stages.firstOrNull { it.status == "active" }
            ?: trip.stages.singleOrNull()
            ?: trip.stages.firstOrNull()

    fun isSameActiveSession(
        activeTripId: String?,
        activeStageId: String?,
        navigating: Boolean,
        requestedTripId: String,
        requestedStageId: String,
    ): Boolean = navigating && activeTripId == requestedTripId && activeStageId == requestedStageId

    fun reroutedStage(
        source: CarStage,
        routeId: String,
        geometry: List<CarPoint>,
        maneuvers: List<CarManeuver>,
        distanceMeters: Int,
        durationSeconds: Int,
    ): CarStage = source.copy(
        id = source.id,
        routeId = routeId,
        geometry = geometry,
        maneuvers = maneuvers,
        distanceMeters = distanceMeters,
        durationSeconds = durationSeconds,
    )
}
