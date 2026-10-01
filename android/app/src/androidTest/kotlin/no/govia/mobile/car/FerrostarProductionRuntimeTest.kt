package no.govia.mobile.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FerrostarProductionRuntimeTest {
    private val stage = stage()

    @Test
    fun providerSemanticsAndAnnotationsSurviveProductionAdapter() {
        val adapted = FerrostarRouteAdapter.convert(stage)
        val weak = adapted.route.steps.first { it.instruction == "Følg veien" }
        val exit = adapted.route.steps.first { it.instruction == "Ta avkjøringen" }
        val roundabout = adapted.route.steps.first { it.instruction == "Ta andre avkjøring" }

        assertTrue(weak.spokenInstructions.isEmpty())
        assertTrue(exit.spokenInstructions.isNotEmpty())
        assertEquals(listOf("7"), exit.exits)
        assertTrue(exit.roundaboutExitNumber == null)
        assertEquals(2u.toUByte(), roundabout.roundaboutExitNumber)
        assertTrue(adapted.route.steps.flatMap { it.annotations.orEmpty() }.any { it.contains("\"speedLimitKph\":80") })
        assertTrue(adapted.route.steps.flatMap { it.annotations.orEmpty() }.any { it.contains("\"speedLimitKph\":60") })
        assertTrue(adapted.route.steps.flatMap { it.annotations.orEmpty() }.any { it.contains("\"speedLimitKph\":40") })
        adapted.route.steps.forEach { step ->
            assertEquals(
                "Ferrostar annotations must be coordinate-aligned with step geometry",
                step.geometry.size,
                step.annotations?.size,
            )
        }
    }


    @Test
    fun duplicateProviderShapeIndexKeepsAnnotationsAligned() {
        val duplicate = stage.copy(
            maneuvers = stage.maneuvers.mapIndexed { index, maneuver ->
                if (index == 1) maneuver.copy(shapeIndex = 0, location = stage.geometry[0]) else maneuver
            },
        )
        val adapted = FerrostarRouteAdapter.convert(duplicate)
        adapted.route.steps.forEach { step ->
            assertEquals(step.geometry.size, step.annotations?.size)
        }
    }

    @Test
    fun runtimeOwnsProgressSnappingSpeedLimitAndArrival() {
        val runtime = FerrostarNavigationRuntime(stage)
        var previous = -1.0
        var sawSnapped = false
        val limits = mutableListOf<Int>()
        for (index in 0..30) {
            val point = stage.geometry[index]
            val state = runtime.update(
                CarNavigationFix(point.lat, point.lon, 18.0, 0.0, 6.0, 1_000L + index * 1_000L),
            )
            assertTrue("Progress regressed at geometry[$index]: previous=$previous current=${state.progressMeters}", state.progressMeters + 0.5 >= previous)
            previous = state.progressMeters
            sawSnapped = sawSnapped || state.snappedLocation != null
            state.speedLimitKph?.let { if (limits.lastOrNull() != it) limits += it }
        }
        assertTrue("No snapped location was surfaced", sawSnapped)
        assertTrue("80 km/h was not surfaced; observed=$limits", limits.contains(80))
        assertTrue("60 km/h was not surfaced; observed=$limits", limits.contains(60))
        assertTrue("40 km/h was not surfaced; observed=$limits", limits.contains(40))
        assertTrue(
            "Speed-limit order did not follow provider path sections; observed=$limits",
            limits.indexOf(80) < limits.indexOf(60) && limits.indexOf(60) < limits.indexOf(40),
        )

        // Arrival is terminal and therefore validated independently from deviation/reroute.
        val destination = stage.geometry.last()
        repeat(3) { n ->
            if (!runtime.state.arrived) {
                runtime.update(
                    CarNavigationFix(destination.lat, destination.lon, 0.0, 0.0, 5.0, 40_000L + n * 1_000L),
                )
            }
        }
        assertTrue("Destination did not reach terminal arrival state: ${runtime.state}", runtime.state.arrived)
        assertEquals(0.0, runtime.state.remainingMeters, 0.5)
    }

    @Test
    fun goodAccuracyDeviationTriggersRerouteBeforeArrival() {
        val runtime = FerrostarNavigationRuntime(stage)
        for (index in 0..8) {
            val point = stage.geometry[index]
            runtime.update(
                CarNavigationFix(point.lat, point.lon, 16.0, 0.0, 6.0, 1_000L + index * 1_000L),
            )
        }
        assertFalse("Trace unexpectedly arrived before deviation test", runtime.state.arrived)

        // Ferrostar computes deviation from the previous navigation state before it applies the
        // new location. Therefore the first off-route fix establishes the raw location and the
        // second consecutive good-accuracy fix must expose the deviation. This is intentional
        // one-fix latency in Ferrostar 0.53.0, not a GoVia debounce.
        val firstOffRoute = CarNavigationFix(
            lat = 59.0300,
            lon = 5.8200,
            speedMetersPerSecond = 20.0,
            headingDegrees = 45.0,
            accuracyMeters = 8.0,
            timestampMillis = 20_000L,
        )
        runtime.update(firstOffRoute)
        val detected = runtime.update(firstOffRoute.copy(timestampMillis = 21_000L))

        assertTrue("Ferrostar did not require reroute on the second consecutive good-accuracy off-route fix: $detected", detected.rerouteRequired)
        assertEquals(CarOffRouteState.OFF_ROUTE, detected.offRouteState)

        val sustained = runtime.update(firstOffRoute.copy(lat = 59.03002, timestampMillis = 22_000L))
        assertTrue("Sustained off-route state unexpectedly cleared: $sustained", sustained.rerouteRequired)
        assertEquals(CarOffRouteState.OFF_ROUTE, sustained.offRouteState)
    }

    @Test
    fun degradedAccuracyDoesNotCreateFalseOffRouteSignal() {
        val runtime = FerrostarNavigationRuntime(stage)
        val point = stage.geometry[8]
        runtime.update(
            CarNavigationFix(point.lat, point.lon, 16.0, 0.0, 6.0, 1_000L),
        )
        val state = runtime.update(
            CarNavigationFix(
                lat = 59.0300,
                lon = 5.8200,
                speedMetersPerSecond = 20.0,
                headingDegrees = 45.0,
                accuracyMeters = 30.0,
                timestampMillis = 2_000L,
            ),
        )
        assertFalse("Degraded GPS accuracy must not trigger reroute: $state", state.rerouteRequired)
        assertEquals(CarOffRouteState.ON_ROUTE, state.offRouteState)
        assertEquals(CarGpsQuality.DEGRADED, state.gpsQuality)
    }

    @Test
    fun rerouteReplacesRouteAtomicallyWithoutChangingStageIdentity() {
        val runtime = FerrostarNavigationRuntime(stage)
        val p = stage.geometry[10]
        runtime.update(CarNavigationFix(p.lat, p.lon, 12.0, 0.0, 6.0, 10_000L))
        val rerouted = stage.copy(routeId = "route-rerouted")
        val state = runtime.replaceRoute(rerouted, runtime.state.currentFix)
        assertEquals(stage.id, state.stageId)
        assertEquals("route-rerouted", state.routeId)
        assertNotNull(runtime.state.currentFix)
    }

    @Test
    fun adapterRejectsUnanchoredProviderManeuverInsteadOfGuessing() {
        val broken = stage.copy(
            maneuvers = stage.maneuvers.mapIndexed { index, maneuver ->
                if (index == 1) maneuver.copy(shapeIndex = null, location = CarPoint(99.0, 99.0)) else maneuver
            },
        )
        val failed = runCatching { FerrostarRouteAdapter.convert(broken) }.isFailure
        assertTrue(failed)
    }

    @Test
    fun weakBendNeverBecomesSpokenDecision() {
        val weak = stage.maneuvers.first { it.instruction == "Følg veien" }
        assertFalse(FerrostarRouteAdapter.isActionable(weak))
    }

    private fun stage(): CarStage {
        val geometry = (0..30).map { i ->
            CarPoint(lon = 5.7000 + i * 0.001, lat = 59.0000 + i * 0.0001)
        }
        return CarStage(
            id = "stage-1",
            day = 1,
            order = 0,
            start = "Start",
            end = "Mål",
            transport = "driving",
            routeId = "route-1",
            distanceMeters = 3000,
            durationSeconds = 240,
            geometry = geometry,
            maneuvers = listOf(
                CarManeuver("depart", 0, "depart", "straight", "Start", "", distanceMeters = 0, distanceFromStartMeters = 0, shapeIndex = 0, location = geometry[0]),
                CarManeuver("weak", 1, "turn", "slight_right", "Følg veien", "", distanceMeters = 700, distanceFromStartMeters = 700, shapeIndex = 7, location = geometry[7]),
                CarManeuver("exit", 2, "off_ramp", "right", "Ta avkjøringen", "E39", distanceMeters = 800, distanceFromStartMeters = 1500, shapeIndex = 15, exit = 7, location = geometry[15]),
                CarManeuver("roundabout", 3, "roundabout", "right", "Ta andre avkjøring", "", distanceMeters = 700, distanceFromStartMeters = 2200, shapeIndex = 22, exit = 2, location = geometry[22]),
                CarManeuver("arrive", 4, "arrive", "straight", "Du er fremme", "", distanceMeters = 800, distanceFromStartMeters = 3000, shapeIndex = 30, location = geometry[30]),
            ),
            speedLimitSections = listOf(
                CarSpeedLimitSection(0, 1000, 80, 0, 10),
                CarSpeedLimitSection(1000, 2000, 60, 10, 20),
                CarSpeedLimitSection(2000, 3000, 40, 20, 30),
            ),
        )
    }
}
