package no.govia.mobile.car

import com.stadiamaps.ferrostar.core.FerrostarSessionBuilder
import java.io.File
import java.time.Instant
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import no.govia.mobile.ferrostar.poc.CanonicalManeuver
import no.govia.mobile.ferrostar.poc.CanonicalPoint
import no.govia.mobile.ferrostar.poc.CanonicalRoute
import no.govia.mobile.ferrostar.poc.CanonicalSpeedLimitSection
import no.govia.mobile.ferrostar.poc.GoViaFerrostarRouteAdapter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.ferrostar.CourseFiltering
import uniffi.ferrostar.CourseOverGround
import uniffi.ferrostar.NavigationControllerConfig
import uniffi.ferrostar.RouteDeviationTracking
import uniffi.ferrostar.Speed
import uniffi.ferrostar.TripState
import uniffi.ferrostar.UserLocation
import uniffi.ferrostar.WaypointAdvanceMode
import uniffi.ferrostar.stepAdvanceDistanceEntryAndExit
import uniffi.ferrostar.stepAdvanceDistanceToEndOfStep

/**
 * PoC-02 acceptance harness.
 *
 * Runs the same provider-anchored route/fixes through the production GoVia NavigationCoreV2 and
 * a real Ferrostar NavigationSession. Nothing here is referenced by the production runtime.
 */
class FerrostarRuntimeComparisonTest {
    private val canonical = buildCanonicalRoute()
    private val ferrostarRoute = GoViaFerrostarRouteAdapter.convert(canonical)
    private val goviaRoute = buildGoViaRoute(canonical)


    @Test
    fun migrationDecisionGateProducesRuntimeReport() {
        val govia = NavigationCoreV2(goviaRoute)
        val session = FerrostarSessionBuilder(config()).build(ferrostarRoute)
        val traceIndexes = listOf(0, 4, 8, 12, 18, 20, 22, 28, 34, 36, 42, 48, 50)
        var navState = session.getInitialState(userLocation(traceIndexes.first(), 10_000L))
        var previousGoViaProgress = -1.0
        var previousFerroRemaining = Double.MAX_VALUE
        val samples = JSONArray()
        val observedLimits = mutableListOf<Int>()

        traceIndexes.forEachIndexed { sample, index ->
            val timestamp = 10_000L + sample * 1_000L
            val point = canonical.geometry[index]
            val goviaState = govia.update(
                CarNavigationFix(point.lat, point.lon, 18.0, 0.0, 6.0, timestamp)
            )
            navState = session.updateUserLocation(userLocation(index, timestamp), navState)

            assertTrue("GoVia progress regressed", goviaState.progressMeters + 0.5 >= previousGoViaProgress)
            previousGoViaProgress = goviaState.progressMeters

            val row = JSONObject()
                .put("sample", sample)
                .put("shapeIndex", index)
                .put("goviaProgressMeters", goviaState.progressMeters)
                .put("goviaManeuverType", goviaState.currentManeuver?.type ?: JSONObject.NULL)
                .put("goviaManeuverModifier", goviaState.currentManeuver?.modifier ?: JSONObject.NULL)

            when (val trip = navState.tripState) {
                is TripState.Navigating -> {
                    assertNotNull("Ferrostar must expose snapped position", trip.snappedUserLocation)
                    assertTrue(
                        "Ferrostar remaining distance regressed unexpectedly",
                        trip.progress.distanceRemaining <= previousFerroRemaining + 25.0,
                    )
                    previousFerroRemaining = trip.progress.distanceRemaining
                    val limit = Regex("\"speedLimitKph\":(\\d+)")
                        .find(trip.annotationJson.orEmpty())
                        ?.groupValues?.getOrNull(1)?.toIntOrNull()
                    if (limit != null && observedLimits.lastOrNull() != limit) observedLimits += limit
                    row
                        .put("ferroState", "navigating")
                        .put("ferroRemainingMeters", trip.progress.distanceRemaining)
                        .put("ferroDistanceToManeuverMeters", trip.progress.distanceToNextManeuver)
                        .put("ferroInstructionType", trip.visualInstruction?.primaryContent?.maneuverType?.toString() ?: JSONObject.NULL)
                        .put("ferroDeviation", trip.deviation.toString())
                        .put("ferroAnnotation", trip.annotationJson ?: JSONObject.NULL)
                        .put("ferroSpeedLimitKph", limit ?: JSONObject.NULL)
                }
                is TripState.Complete -> row.put("ferroState", "complete")
                is TripState.Idle -> row.put("ferroState", "idle")
            }
            samples.put(row)
        }

        // Provider-anchored annotations must survive the runtime in route order.
        assertTrue("Ferrostar did not expose 80 km/h provider annotation", observedLimits.contains(80))
        assertTrue("Ferrostar did not expose 60 km/h provider annotation", observedLimits.contains(60))
        assertTrue("Ferrostar did not expose 40 km/h provider annotation", observedLimits.contains(40))
        assertTrue("Speed limits were not observed in provider route order: $observedLimits",
            observedLimits.indexOf(80) < observedLimits.indexOf(60) && observedLimits.indexOf(60) < observedLimits.indexOf(40))

        val weak = ferrostarRoute.steps.first { it.instruction == "Følg veien" }
        val exit = ferrostarRoute.steps.first { it.instruction == "Ta avkjøringen" }
        val roundabout = ferrostarRoute.steps.first { it.instruction == "Ta andre avkjøring" }
        assertTrue("Weak bend must remain silent", weak.spokenInstructions.isEmpty())
        assertTrue("Motorway exit must remain actionable", exit.spokenInstructions.isNotEmpty())
        assertEquals(listOf("7"), exit.exits)
        assertEquals(2u.toUByte(), roundabout.roundaboutExitNumber)

        // Repeated credible off-route fixes must be visible as deviation, not silently snapped forever.
        repeat(7) { n ->
            val offRoute = UserLocation(
                coordinates = uniffi.ferrostar.GeographicCoordinate(lat = 59.0300 + n * 0.00002, lng = 5.8200),
                horizontalAccuracy = 8.0,
                courseOverGround = CourseOverGround(degrees = 45u.toUShort(), accuracy = 5u.toUShort()),
                timestamp = Instant.ofEpochMilli(30_000L + n * 1_000L),
                speed = Speed(value = 20.0, accuracy = 1.0),
            )
            navState = session.updateUserLocation(offRoute, navState)
        }
        val finalTrip = navState.tripState
        val finalDeviation = if (finalTrip is TripState.Navigating) finalTrip.deviation.toString() else finalTrip.toString()
        assertTrue("Repeated off-route fixes never produced a deviation: $finalDeviation", !finalDeviation.contains("NoDeviation"))

        val report = JSONObject()
            .put("release", "0.1.113+114")
            .put("decisionGate", "ferrostar-migration")
            .put("observedSpeedLimitsKph", JSONArray(observedLimits))
            .put("finalFerrostarDeviation", finalDeviation)
            .put("samples", samples)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        File(context.cacheDir, "govia-ferrostar-runtime-report.json").writeText(report.toString(2))
        println("POC03_REPORT ${report}")
    }

    @Test
    fun sameTraceRunsThroughBothRealRuntimesWithMonotonicProgress() {
        val govia = NavigationCoreV2(goviaRoute)
        val session = FerrostarSessionBuilder(config()).build(ferrostarRoute)
        val traceIndexes = listOf(0, 4, 8, 12, 18, 20, 22, 28, 34, 36, 42, 48, 50)

        var previousGoViaProgress = -1.0
        var previousFerrostarRemaining = Double.MAX_VALUE
        var navState = session.getInitialState(userLocation(traceIndexes.first(), 1_000L))
        var sawFerrostarNavigating = false
        var sawProviderSpeedAnnotation = false

        traceIndexes.forEachIndexed { sample, index ->
            val timestamp = 1_000L + sample * 1_000L
            val point = canonical.geometry[index]
            val goviaState = govia.update(
                CarNavigationFix(
                    lat = point.lat,
                    lon = point.lon,
                    speedMetersPerSecond = 18.0,
                    headingDegrees = 0.0,
                    accuracyMeters = 6.0,
                    timestampMillis = timestamp,
                )
            )
            navState = session.updateUserLocation(userLocation(index, timestamp), navState)

            assertTrue("GoVia progress regressed", goviaState.progressMeters + 0.5 >= previousGoViaProgress)
            previousGoViaProgress = goviaState.progressMeters

            when (val trip = navState.tripState) {
                is TripState.Navigating -> {
                    sawFerrostarNavigating = true
                    assertNotNull("Ferrostar must expose a snapped route position", trip.snappedUserLocation)
                    assertTrue(
                        "Ferrostar remaining distance regressed unexpectedly: ${trip.progress.distanceRemaining} > $previousFerrostarRemaining",
                        trip.progress.distanceRemaining <= previousFerrostarRemaining + 25.0,
                    )
                    previousFerrostarRemaining = trip.progress.distanceRemaining
                    if (trip.annotationJson?.contains("speedLimitKph") == true) {
                        sawProviderSpeedAnnotation = true
                    }
                    println(
                        "POC02 sample=$sample shapeIndex=$index " +
                            "goviaProgress=${"%.1f".format(goviaState.progressMeters)} " +
                            "goviaManeuver=${goviaState.currentManeuver?.type}/${goviaState.currentManeuver?.modifier} " +
                            "ferroRemaining=${"%.1f".format(trip.progress.distanceRemaining)} " +
                            "ferroInstruction=${trip.visualInstruction?.primaryContent?.maneuverType} " +
                            "ferroDeviation=${trip.deviation} annotation=${trip.annotationJson}"
                    )
                }
                is TripState.Complete -> previousFerrostarRemaining = 0.0
                is TripState.Idle -> Unit
            }
        }

        assertTrue("Ferrostar session never entered Navigating", sawFerrostarNavigating)
        assertTrue("Provider speed-limit annotation was never surfaced by Ferrostar runtime", sawProviderSpeedAnnotation)
    }

    @Test
    fun canonicalExitAndWeakBendRemainSemanticallyDifferentAtRuntimeBoundary() {
        val weak = ferrostarRoute.steps.first { it.instruction == "Følg veien" }
        val exit = ferrostarRoute.steps.first { it.instruction == "Ta avkjøringen" }

        assertTrue("Weak bend must stay silent", weak.spokenInstructions.isEmpty())
        assertTrue("Motorway exit must remain actionable", exit.spokenInstructions.isNotEmpty())
        assertEquals("Exit number must survive provider -> Ferrostar mapping", listOf("7"), exit.exits)
    }

    @Test
    fun gpsJumpDoesNotMoveGoViaProgressBackwardsAndFerrostarKeepsSnappedState() {
        val govia = NavigationCoreV2(goviaRoute)
        val session = FerrostarSessionBuilder(config()).build(ferrostarRoute)

        var navState = session.getInitialState(userLocation(10, 1_000L))
        val before = govia.update(fixAt(10, 1_000L))
        navState = session.updateUserLocation(userLocation(10, 1_000L), navState)

        // Deliberate large raw GPS excursion; same trace is sent to both runtimes.
        val jump = UserLocation(
            coordinates = uniffi.ferrostar.GeographicCoordinate(lat = 59.0300, lng = 5.8200),
            horizontalAccuracy = 8.0,
            courseOverGround = CourseOverGround(degrees = 45u.toUShort(), accuracy = 5u.toUShort()),
            timestamp = Instant.ofEpochMilli(2_000L),
            speed = Speed(value = 20.0, accuracy = 1.0),
        )
        val goviaJump = govia.update(
            CarNavigationFix(59.0300, 5.8200, 20.0, 45.0, 8.0, 2_000L)
        )
        navState = session.updateUserLocation(jump, navState)

        assertTrue("GoVia must not move progress backwards on GPS jump", goviaJump.progressMeters >= before.progressMeters)
        val trip = navState.tripState
        if (trip is TripState.Navigating) {
            assertNotNull(trip.snappedUserLocation)
            println("POC02 gpsJump ferroDeviation=${trip.deviation} snapped=${trip.snappedUserLocation.coordinates}")
        }
    }

    private fun config() = NavigationControllerConfig(
        WaypointAdvanceMode.WaypointWithinRange(80.0),
        stepAdvanceDistanceEntryAndExit(30u, 5u, 32u),
        stepAdvanceDistanceToEndOfStep(10u, 32u),
        RouteDeviationTracking.StaticThreshold(5u, 55.0),
        CourseFiltering.SNAP_TO_ROUTE,
    )

    private fun userLocation(index: Int, timestamp: Long): UserLocation {
        val p = canonical.geometry[index]
        return UserLocation(
            coordinates = uniffi.ferrostar.GeographicCoordinate(lat = p.lat, lng = p.lon),
            horizontalAccuracy = 6.0,
            courseOverGround = CourseOverGround(degrees = 0u.toUShort(), accuracy = 5u.toUShort()),
            timestamp = Instant.ofEpochMilli(timestamp),
            speed = Speed(value = 18.0, accuracy = 1.0),
        )
    }

    private fun fixAt(index: Int, timestamp: Long): CarNavigationFix {
        val p = canonical.geometry[index]
        return CarNavigationFix(p.lat, p.lon, 18.0, 0.0, 6.0, timestamp)
    }

    private fun buildGoViaRoute(route: CanonicalRoute): CarNavigationRoute {
        val geometry = route.geometry.map { CarPoint(lon = it.lon, lat = it.lat) }
        val maneuvers = route.maneuvers.mapIndexed { sequence, m ->
            CarAnchoredManeuver(
                maneuver = CarManeuver(
                    id = m.id,
                    sequence = sequence,
                    type = m.type,
                    modifier = m.modifier,
                    instruction = m.instruction,
                    roadName = m.roadName,
                    roadRef = m.roadRef,
                    distanceMeters = 0,
                    durationSeconds = 0,
                    distanceFromStartMeters = m.routeOffsetMeters.toInt(),
                    exit = m.exitNumber,
                    source = "tomtom",
                    confidence = 1.0,
                    location = geometry[m.shapeIndex],
                ),
                shapeIndex = m.shapeIndex,
                routeProgressMeters = m.routeOffsetMeters,
            )
        }
        return CarNavigationRoute(
            stageId = "poc02-stage",
            routeId = "poc02-route",
            destinationName = "PoC destination",
            transport = "car",
            geometry = geometry,
            maneuvers = maneuvers,
            distanceMeters = route.distanceMeters.toInt(),
            durationSeconds = route.durationSeconds.toInt(),
            routeProfile = "fastest",
            routePreferences = CarRoutePreferences(),
        )
    }

    private fun buildCanonicalRoute(): CanonicalRoute {
        // ~5 km synthetic road with enough geometry density to exercise runtime snapping/progress.
        val points = (0..50).map { i ->
            val t = i / 50.0
            val lon = 5.7000 + t * 0.0700 + if (i in 9..14) (i - 9) * 0.00008 else 0.0
            val lat = 58.9700 + t * 0.0350
            CanonicalPoint(lon = lon, lat = lat)
        }
        return CanonicalRoute(
            geometry = points,
            distanceMeters = 5_000.0,
            durationSeconds = 300.0,
            maneuvers = listOf(
                CanonicalManeuver("depart", "depart", "straight", "Start", routeOffsetMeters = 0.0, shapeIndex = 0),
                CanonicalManeuver("bend", "turn", "slight_right", "Følg veien", routeOffsetMeters = 1_000.0, shapeIndex = 10),
                CanonicalManeuver("exit", "off_ramp", "right", "Ta avkjøringen", roadName = "Motorveiavkjøring", roadRef = "E39", routeOffsetMeters = 2_100.0, shapeIndex = 21, exitNumber = 7),
                CanonicalManeuver("roundabout", "roundabout", "right", "Ta andre avkjøring", routeOffsetMeters = 3_500.0, shapeIndex = 35, exitNumber = 2),
                CanonicalManeuver("arrive", "arrive", "straight", "Du er fremme", routeOffsetMeters = 5_000.0, shapeIndex = 50),
            ),
            speedLimits = listOf(
                CanonicalSpeedLimitSection(0, 21, 80),
                CanonicalSpeedLimitSection(21, 35, 60),
                CanonicalSpeedLimitSection(35, 50, 40),
            ),
        )
    }
}
