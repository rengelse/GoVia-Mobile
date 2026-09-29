package no.govia.mobile.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NavigationCoreV2Test {
    private fun stage(
        id: String = "stage-1",
        routeId: String = "route-1",
        maneuverDistance: Int = 900,
        geometry: List<CarPoint> = listOf(
            CarPoint(5.0, 60.0),
            CarPoint(5.0, 60.005),
            CarPoint(5.0, 60.01),
        ),
        maneuvers: List<CarManeuver>? = null,
        waypoints: List<CarWaypoint> = listOf(
            CarWaypoint("poi-1", "Utsikt", "poi", "utsikt", distanceFromStartMeters = 300, location = CarPoint(5.0, 60.003)),
        ),
    ): CarStage = CarStage(
        id = id,
        day = 1,
        order = 1,
        start = "Start",
        end = "Mål",
        transport = "car",
        name = "Etappe",
        status = "active",
        routeId = routeId,
        waypoints = waypoints,
        distanceMeters = 1112,
        durationSeconds = 100,
        geometry = geometry,
        maneuvers = maneuvers ?: listOf(
            CarManeuver(
                id = "turn-1",
                sequence = 0,
                type = "turn",
                modifier = "right",
                instruction = "Sving til høyre",
                roadName = "Testveien",
                distanceMeters = 0,
                distanceFromStartMeters = maneuverDistance,
                location = geometry[1],
            ),
        ),
    )

    @Test
    fun `maneuver is anchored to geometry rather than backend distance`() {
        val route = CarNavigationRoute.fromStage(stage(maneuverDistance = 900))
        val anchored = route.maneuvers.single()
        assertTrue(anchored.routeProgressMeters in 530.0..580.0)
    }

    @Test
    fun `loop maneuvers at same coordinate preserve forward route order`() {
        val a = CarPoint(5.0, 60.0)
        val b = CarPoint(5.0, 60.001)
        val c = CarPoint(5.001, 60.001)
        val geometry = listOf(a, b, c, b, a)
        val maneuvers = listOf(
            CarManeuver("m1", 0, instruction = "Første passering", roadName = "", distanceMeters = 0, distanceFromStartMeters = 110, location = b),
            CarManeuver("m2", 1, instruction = "Andre passering", roadName = "", distanceMeters = 0, distanceFromStartMeters = 330, location = b),
        )
        val anchored = CarNavigationRoute.fromStage(stage(geometry = geometry, maneuvers = maneuvers)).maneuvers
        assertTrue(anchored[1].routeProgressMeters > anchored[0].routeProgressMeters + 100.0)
        assertTrue(anchored[1].shapeIndex >= anchored[0].shapeIndex)
    }

    @Test
    fun `arrival requires three credible fixes and remains terminal`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        fun update(lat: Double, second: Long) = core.update(CarNavigationFix(lat, 5.0, 0.0, 0.0, 8.0, second * 1000L))
        assertFalse(update(60.01, 1).arrived)
        assertFalse(update(60.01, 2).arrived)
        val arrived = update(60.01, 3)
        assertTrue(arrived.arrived)
        val after = update(60.008, 4)
        assertTrue(after.arrived)
        assertEquals(arrived.progressMeters, after.progressMeters, 0.01)
        assertEquals(CarArrivalState.ARRIVED, after.arrivalState)
    }

    @Test
    fun `stale GPS fix cannot advance progress or replace accepted fix`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        val accepted = core.update(CarNavigationFix(60.002, 5.0, 8.0, 0.0, 8.0, 2_000L))
        val stale = core.update(CarNavigationFix(60.0025, 5.0, 8.0, 0.0, 8.0, 1_000L))
        assertEquals(accepted.progressMeters, stale.progressMeters, 0.01)
        assertEquals(accepted.currentFix?.timestampMillis, stale.currentFix?.timestampMillis)
    }

    @Test
    fun `off route requires repeated credible fixes`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        fun update(second: Long) = core.update(CarNavigationFix(60.005, 5.01, 10.0, 0.0, 8.0, second * 1000L))
        assertEquals(CarOffRouteState.SUSPECT, update(1).offRouteState)
        assertEquals(CarOffRouteState.SUSPECT, update(2).offRouteState)
        assertEquals(CarOffRouteState.OFF_ROUTE, update(3).offRouteState)
    }

    @Test
    fun `poor accuracy does not advance existing route state`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        val first = core.update(CarNavigationFix(60.001, 5.0, 8.0, 0.0, 8.0, 1_000L))
        val poor = core.update(CarNavigationFix(60.009, 5.0, 8.0, 0.0, 150.0, 2_000L))
        assertEquals(CarGpsQuality.POOR, poor.gpsQuality)
        assertEquals(first.progressMeters, poor.progressMeters, 0.01)
    }

    @Test
    fun `poor first fix cannot initialize progress or arrival`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        val poor = core.update(CarNavigationFix(60.01, 5.0, 0.0, 0.0, 150.0, 1_000L))
        assertEquals(CarGpsQuality.POOR, poor.gpsQuality)
        assertEquals(0.0, poor.progressMeters, 0.01)
        assertFalse(poor.arrived)
    }

    @Test
    fun `unknown accuracy is conservative and cannot trigger arrival or progress`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        val unknown = core.update(CarNavigationFix(60.01, 5.0, 0.0, 0.0, 0.0, 1_000L))
        assertEquals(CarGpsQuality.UNKNOWN, unknown.gpsQuality)
        assertEquals(0.0, unknown.progressMeters, 0.01)
        assertFalse(unknown.arrived)
    }

    @Test
    fun `snapshot restore retains progress and segment continuity`() {
        val route = CarNavigationRoute.fromStage(stage())
        val core = NavigationCoreV2(route)
        val before = core.update(CarNavigationFix(60.004, 5.0, 10.0, 0.0, 8.0, 1_000L))
        val restored = NavigationCoreV2(route)
        restored.restore(core.snapshot())
        val after = restored.update(CarNavigationFix(60.0042, 5.0, 10.0, 0.0, 8.0, 2_000L))
        assertTrue(after.progressMeters >= before.progressMeters)
        assertTrue(after.matchedSegmentIndex >= before.matchedSegmentIndex)
    }

    @Test
    fun `same active stage is recognized as reattach not a new session`() {
        assertTrue(NavigationHardening.isSameActiveSession("trip-1", "stage-1", true, "trip-1", "stage-1"))
        assertFalse(NavigationHardening.isSameActiveSession("trip-1", "stage-1", true, "trip-1", "stage-2"))
    }

    @Test
    fun `reroute preserves stage identity and reprojects poi onto new geometry`() {
        val source = stage(
            routeId = "route-original",
            waypoints = listOf(CarWaypoint("poi-1", "Utsikt", "poi", "utsikt", distanceFromStartMeters = 900, location = CarPoint(5.0, 60.004))),
        )
        val newGeometry = listOf(
            CarPoint(5.0, 60.0),
            CarPoint(5.0, 60.002),
            CarPoint(5.0, 60.004),
            CarPoint(5.0, 60.01),
        )
        val rerouted = NavigationHardening.reroutedStage(
            source = source,
            routeId = "route-reroute-2",
            geometry = newGeometry,
            maneuvers = source.maneuvers,
            distanceMeters = 1200,
            durationSeconds = 120,
        )
        assertEquals(source.id, rerouted.id)
        assertNotEquals(source.routeId, rerouted.routeId)
        assertEquals(source.name, rerouted.name)
        assertEquals(source.status, rerouted.status)
        assertTrue(rerouted.waypoints.single().distanceFromStartMeters in 420..470)
    }

    @Test
    fun `stale reroute result is rejected when route or revision changed`() {
        assertTrue(NavigationHardening.canApplyReroute(
            "trip-1", "stage-1", "route-1", 7,
            "trip-1", "stage-1", "route-1", 7,
        ))
        assertFalse(NavigationHardening.canApplyReroute(
            "trip-1", "stage-1", "route-2", 8,
            "trip-1", "stage-1", "route-1", 7,
        ))
        assertFalse(NavigationHardening.canApplyReroute(
            "trip-1", "stage-2", "route-1", 7,
            "trip-1", "stage-1", "route-1", 7,
        ))
    }

    @Test
    fun `route replacement cannot change active stage identity`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage(id = "stage-a", routeId = "route-a")))
        val wrongStage = CarNavigationRoute.fromStage(stage(id = "stage-b", routeId = "route-b"))
        var failed = false
        try {
            core.replaceRoute(wrongStage)
        } catch (_: IllegalArgumentException) {
            failed = true
        }
        assertTrue(failed)
    }

    @Test
    fun `preferred stage selection survives multi stage recovery`() {
        val first = stage(id = "stage-1")
        val third = stage(id = "stage-3")
        val trip = CarTrip("trip-1", "Tur", "A", "C", "active", listOf(first, third))
        assertEquals("stage-3", NavigationHardening.selectStage(trip, "stage-3")?.id)
    }

    @Test
    fun `typed maneuver survives canonical route`() {
        val route = CarNavigationRoute.fromStage(stage())
        assertNotNull(route.maneuvers.single().maneuver)
        assertEquals("turn", route.maneuvers.single().maneuver.type)
        assertEquals("right", route.maneuvers.single().maneuver.modifier)
        assertEquals("route-1", route.routeId)
    }
}
