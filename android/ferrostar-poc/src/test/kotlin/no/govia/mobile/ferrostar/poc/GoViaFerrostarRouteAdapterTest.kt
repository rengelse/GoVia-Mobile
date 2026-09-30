package no.govia.mobile.ferrostar.poc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.ferrostar.ManeuverType

class GoViaFerrostarRouteAdapterTest {
    private val route = CanonicalRoute(
        geometry = listOf(
            CanonicalPoint(5.7000, 58.9700),
            CanonicalPoint(5.7010, 58.9705),
            CanonicalPoint(5.7020, 58.9710),
            CanonicalPoint(5.7030, 58.9715),
            CanonicalPoint(5.7040, 58.9720),
            CanonicalPoint(5.7050, 58.9725),
        ),
        distanceMeters = 5000.0,
        durationSeconds = 300.0,
        maneuvers = listOf(
            CanonicalManeuver("depart", "depart", "straight", "Start", routeOffsetMeters = 0.0, shapeIndex = 0),
            // A weak road bend must not produce speech.
            CanonicalManeuver("bend", "turn", "slight_right", "Følg veien", routeOffsetMeters = 900.0, shapeIndex = 1),
            // This is the key acceptance case that current GoVia missed in real driving.
            CanonicalManeuver("exit", "off_ramp", "right", "Ta avkjøringen", roadRef = "E39", routeOffsetMeters = 2100.0, shapeIndex = 2, exitNumber = 7),
            CanonicalManeuver("roundabout", "roundabout", "right", "Ta andre avkjøring", routeOffsetMeters = 3500.0, shapeIndex = 4, exitNumber = 2),
            CanonicalManeuver("arrive", "arrive", "straight", "Du er fremme", routeOffsetMeters = 5000.0, shapeIndex = 5),
        ),
        speedLimits = listOf(
            CanonicalSpeedLimitSection(0, 2, 80),
            CanonicalSpeedLimitSection(2, 4, 60),
            CanonicalSpeedLimitSection(4, 5, 40),
        ),
    )

    @Test
    fun adapterPreservesCanonicalExitAndRoundaboutSemantics() {
        val ferrostar = GoViaFerrostarRouteAdapter.convert(route)
        assertEquals(route.geometry.size, ferrostar.geometry.size)
        assertEquals(route.maneuvers.size, ferrostar.steps.size)
        assertEquals(ManeuverType.OFF_RAMP, ferrostar.steps[2].visualInstructions.first().primaryContent.maneuverType)
        assertEquals(listOf("7"), ferrostar.steps[2].exits)
        assertEquals(ManeuverType.ROUNDABOUT, ferrostar.steps[3].visualInstructions.first().primaryContent.maneuverType)
        assertEquals(2u.toUByte(), ferrostar.steps[3].roundaboutExitNumber)
    }

    @Test
    fun weakBendIsNotPromotedToSpokenGuidance() {
        val ferrostar = GoViaFerrostarRouteAdapter.convert(route)
        assertTrue(ferrostar.steps[1].spokenInstructions.isEmpty())
        assertFalse(ferrostar.steps[2].spokenInstructions.isEmpty())
    }

    @Test
    fun speedLimitsAreAnchoredByProviderPathIndexWithoutCarryForward() {
        val ferrostar = GoViaFerrostarRouteAdapter.convert(route)
        val annotations = ferrostar.steps.flatMap { it.annotations ?: emptyList() }
        assertTrue(annotations.any { it.contains("80") })
        assertTrue(annotations.any { it.contains("60") })
        assertTrue(annotations.any { it.contains("40") })
    }

    @Test(expected = IllegalArgumentException::class)
    fun adapterContractRejectsUnanchoredManeuver() {
        CanonicalRoute(
            geometry = route.geometry,
            distanceMeters = 100.0,
            durationSeconds = 10.0,
            maneuvers = listOf(
                CanonicalManeuver("bad", "turn", "right", "Sving", routeOffsetMeters = 50.0, shapeIndex = 99),
            ),
            speedLimits = emptyList(),
        )
    }
}
