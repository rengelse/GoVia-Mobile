package no.govia.mobile.car

private fun checkThat(value: Boolean, message: String) {
    if (!value) error(message)
}

private fun stage(routeId: String = "route-1") = CarStage(
    id = "stage-1",
    day = 1,
    order = 0,
    start = "A",
    end = "B",
    transport = "car",
    routeId = routeId,
    distanceMeters = 1112,
    durationSeconds = 100,
    geometry = listOf(CarPoint(5.0, 60.0), CarPoint(5.0, 60.01)),
    maneuvers = listOf(
        CarManeuver(
            id = "m1",
            sequence = 0,
            type = "turn",
            modifier = "right",
            instruction = "Sving til høyre",
            roadName = "Testveien",
            distanceMeters = 100,
            distanceFromStartMeters = 500,
            location = CarPoint(5.0, 60.0045),
        ),
    ),
)

fun main() {
    val route = CarNavigationRoute.fromStage(stage())
    val core = NavigationCoreV2(route)
    val first = core.update(CarNavigationFix(60.002, 5.0, 8.0, 0.0, 8.0, 1_000L))
    val poor = core.update(CarNavigationFix(60.003, 5.0, 8.0, 0.0, 150.0, 3_000L))
    val stale = core.update(CarNavigationFix(60.006, 5.0, 8.0, 0.0, 8.0, 2_000L))
    checkThat(first.progressMeters > 150.0, "normal progress failed")
    checkThat(poor.progressMeters == first.progressMeters, "poor fix advanced progress")
    checkThat(stale.progressMeters == first.progressMeters, "stale fix advanced progress")

    val restored = NavigationCoreV2(route)
    restored.restore(core.snapshot())
    checkThat(restored.state?.progressMeters == first.progressMeters, "snapshot restore failed")

    val rerouted = CarNavigationRoute.fromStage(stage(routeId = "route-2"))
    restored.replaceRoute(rerouted)
    checkThat(restored.plannedRoute.routeId == "route-1", "planned route was overwritten")
    checkThat(restored.activeRoute.routeId == "route-2", "active route was not replaced")

    val arrivalCore = NavigationCoreV2(route)
    arrivalCore.update(CarNavigationFix(60.01, 5.0, 0.0, 0.0, 8.0, 1_000L))
    arrivalCore.update(CarNavigationFix(60.01, 5.0, 0.0, 0.0, 8.0, 2_000L))
    val arrived = arrivalCore.update(CarNavigationFix(60.01, 5.0, 0.0, 0.0, 8.0, 3_000L))
    checkThat(arrived.arrived, "arrival failed")
    val after = arrivalCore.update(CarNavigationFix(60.008, 5.0, 0.0, 0.0, 8.0, 4_000L))
    checkThat(after.arrived, "arrival was not terminal")


    val trip = CarTrip("trip-1", "Tur", "A", "C", "active", listOf(stage("route-1"), stage("route-3").copy(id = "stage-3")))
    checkThat(NavigationHardening.selectStage(trip, "stage-3")?.id == "stage-3", "multi-stage selection failed")

    val offRouteCore = NavigationCoreV2(route)
    fun offRouteFix(t: Long) = offRouteCore.update(CarNavigationFix(60.005, 5.02, 5.0, 0.0, 8.0, t))
    checkThat(offRouteFix(1_000L).offRouteState == CarOffRouteState.SUSPECT, "off-route hysteresis step 1 failed")
    checkThat(offRouteFix(2_000L).offRouteState == CarOffRouteState.SUSPECT, "off-route hysteresis step 2 failed")
    checkThat(offRouteFix(3_000L).offRouteState == CarOffRouteState.OFF_ROUTE, "off-route hysteresis failed")

    val unknownCore = NavigationCoreV2(route)
    val unknown = unknownCore.update(CarNavigationFix(60.009, 5.0, 0.0, 0.0, 0.0, 1_000L))
    checkThat(unknown.gpsQuality == CarGpsQuality.UNKNOWN && unknown.progressMeters == 0.0, "unknown GPS was not conservative")

    val loopGeometry = listOf(
        CarPoint(5.000, 60.000),
        CarPoint(5.006, 60.006),
        CarPoint(5.000, 60.012),
        CarPoint(4.994, 60.006),
        CarPoint(5.000, 60.000),
        CarPoint(5.006, 59.994),
    )
    val loopManeuvers = listOf(
        CarManeuver("a", 0, instruction = "Første kryss", roadName = "A", distanceMeters = 100, distanceFromStartMeters = 500, location = CarPoint(5.000, 60.000)),
        CarManeuver("b", 1, instruction = "Andre kryss", roadName = "B", distanceMeters = 100, distanceFromStartMeters = 2600, location = CarPoint(5.000, 60.000)),
    )
    val loopStage = stage().copy(geometry = loopGeometry, maneuvers = loopManeuvers, distanceMeters = 3500)
    val loopRoute = CarNavigationRoute.fromStage(loopStage)
    checkThat(loopRoute.maneuvers[1].routeProgressMeters >= loopRoute.maneuvers[0].routeProgressMeters, "loop maneuver anchors regressed")
    checkThat(loopRoute.maneuvers[1].shapeIndex >= loopRoute.maneuvers[0].shapeIndex, "loop shape index regressed")

    val reroutedStage = NavigationHardening.reroutedStage(
        source = stage().copy(waypoints = listOf(CarWaypoint("p1", "POI", "poi", distanceFromStartMeters = 900, location = CarPoint(5.0, 60.004)))),
        routeId = "route-reroute",
        geometry = listOf(CarPoint(5.0, 60.0), CarPoint(5.0, 60.004), CarPoint(5.0, 60.01)),
        maneuvers = stage().maneuvers,
        distanceMeters = 1100,
        durationSeconds = 100,
    )
    checkThat(reroutedStage.id == "stage-1", "reroute changed stage identity")
    checkThat(reroutedStage.routeId == "route-reroute", "reroute route identity did not change")
    checkThat(reroutedStage.waypoints.single().distanceFromStartMeters in 420..470, "reroute waypoint reprojection failed")

    checkThat(!NavigationHardening.shouldRunForegroundNavigation(false, false, false), "idle service would enter foreground")
    checkThat(NavigationHardening.shouldRunForegroundNavigation(false, true, false), "explicit navigation start rejected")
    checkThat(NavigationHardening.shouldRunForegroundNavigation(false, false, true), "recovery navigation rejected")

    println("Navigation Core v2 Kotlin smoke: PASS")
}
