package no.govia.mobile.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NavigationCoreV2Test {
    private fun stage(maneuverDistance: Int = 900): CarStage {
        val geometry = listOf(
            CarPoint(5.0, 60.0),
            CarPoint(5.0, 60.005),
            CarPoint(5.0, 60.01),
        )
        return CarStage(
            id = "stage-1",
            day = 1,
            order = 1,
            start = "Start",
            end = "Mål",
            transport = "car",
            distanceMeters = 1112,
            durationSeconds = 100,
            geometry = geometry,
            maneuvers = listOf(
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
    }

    @Test
    fun `maneuver is anchored to geometry rather than backend distance`() {
        val route = CarNavigationRoute.fromStage(stage(maneuverDistance = 900))
        val anchored = route.maneuvers.single()
        assertTrue(anchored.routeProgressMeters in 530.0..580.0)
        assertTrue(anchored.shapeIndex in 0..1)
    }

    @Test
    fun `arrival requires three credible fixes`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        fun update(second: Long) = core.update(
            CarNavigationFix(60.01, 5.0, 0.0, 0.0, 8.0, second * 1000L),
        )
        assertFalse(update(1).arrived)
        assertFalse(update(2).arrived)
        assertTrue(update(3).arrived)
    }

    @Test
    fun `off route requires repeated credible fixes`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        fun update(second: Long) = core.update(
            CarNavigationFix(60.005, 5.01, 10.0, 0.0, 8.0, second * 1000L),
        )
        assertEquals(CarOffRouteState.SUSPECT, update(1).offRouteState)
        assertEquals(CarOffRouteState.SUSPECT, update(2).offRouteState)
        assertEquals(CarOffRouteState.OFF_ROUTE, update(3).offRouteState)
    }

    @Test
    fun `poor accuracy does not advance route state`() {
        val core = NavigationCoreV2(CarNavigationRoute.fromStage(stage()))
        val first = core.update(CarNavigationFix(60.001, 5.0, 8.0, 0.0, 8.0, 1000L))
        val poor = core.update(CarNavigationFix(60.009, 5.0, 8.0, 0.0, 150.0, 2000L))
        assertEquals(CarGpsQuality.POOR, poor.gpsQuality)
        assertEquals(first.progressMeters, poor.progressMeters, 0.01)
    }

    @Test
    fun `typed maneuver survives canonical route`() {
        val route = CarNavigationRoute.fromStage(stage())
        assertNotNull(route.maneuvers.single().maneuver)
        assertEquals("turn", route.maneuvers.single().maneuver.type)
        assertEquals("right", route.maneuvers.single().maneuver.modifier)
    }
}
