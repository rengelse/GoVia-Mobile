package no.govia.mobile.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NavigationGuidanceV1Test {
    private fun maneuver(
        id: String = "m1",
        type: String = "turn",
        modifier: String = "right",
        instruction: String = "Sving til høyre",
        roadName: String = "Bergen sentrum",
        roadRef: String = "E39",
        exit: Int? = null,
        source: String = "provider",
        confidence: Double = 1.0,
    ) = CarManeuver(
        id = id,
        sequence = 0,
        type = type,
        modifier = modifier,
        instruction = instruction,
        roadName = roadName,
        roadRef = roadRef,
        distanceMeters = 0,
        distanceFromStartMeters = 500,
        exit = exit,
        source = source,
        confidence = confidence,
        location = CarPoint(5.0, 60.0),
    )

    @Test
    fun `prepare moves earlier with speed`() {
        val city = NavigationGuidanceV1.thresholds(30.0 / 3.6)
        val motorway = NavigationGuidanceV1.thresholds(110.0 / 3.6)
        assertTrue(motorway.prepareMeters > city.prepareMeters)
        assertEquals(300.0, city.prepareMeters, 0.01)
        assertTrue(motorway.prepareMeters > 800.0)
    }

    @Test
    fun `prepare approach now are deterministic`() {
        val speed = 80.0 / 3.6
        assertEquals(CarGuidancePhase.PREPARE, NavigationGuidanceV1.phaseFor(600.0, speed))
        assertEquals(CarGuidancePhase.APPROACH, NavigationGuidanceV1.phaseFor(200.0, speed))
        assertEquals(CarGuidancePhase.NOW, NavigationGuidanceV1.phaseFor(50.0, speed))
    }

    @Test
    fun `roundabout uses structured exit metadata`() {
        val text = NavigationGuidanceV1.primaryInstruction(
            maneuver(type = "roundabout", modifier = "", instruction = "Roundabout", roadName = "Bergen", roadRef = "E39", exit = 3),
        )
        assertEquals("I rundkjøringen, ta tredje avkjøring mot E39 Bergen", text)
    }

    @Test
    fun `roundabout without exit never degrades to slight right`() {
        val text = NavigationGuidanceV1.primaryInstruction(
            maneuver(type = "roundabout", modifier = "slight_right", instruction = "Sving svakt til høyre", roadName = "", roadRef = ""),
        )
        assertEquals("Kjør inn i rundkjøringen", text)
    }

    @Test
    fun `off ramp without number says next exit`() {
        val text = NavigationGuidanceV1.primaryInstruction(
            maneuver(type = "off_ramp", modifier = "right", instruction = "Sving til høyre", roadName = "Fjøsangerveien", roadRef = "E39"),
        )
        assertEquals("Ta neste avkjøring mot E39 Fjøsangerveien", text)
    }

    @Test
    fun `geometry only turn is silent`() {
        val cue = NavigationGuidanceV1.cueFor(
            maneuver(type = "turn", modifier = "right", source = "geometry-emergency", confidence = 0.25),
            120.0,
            15.0,
        )
        assertEquals(null, cue)
    }

    @Test
    fun `informational steps are silent`() {
        assertEquals(null, NavigationGuidanceV1.cueFor(maneuver(type = "new_name", modifier = "slight_right"), 120.0, 15.0))
        assertEquals(null, NavigationGuidanceV1.cueFor(maneuver(type = "notification", modifier = "left"), 120.0, 15.0))
    }

    @Test
    fun `continue ignores curvature modifier`() {
        assertEquals("Fortsett på E39", NavigationGuidanceV1.primaryInstruction(maneuver(type = "continue", modifier = "slight_right", roadName = "E39", roadRef = "")))
    }

    @Test
    fun `fork and on ramp retain structured semantics`() {
        assertEquals("Hold til venstre", NavigationGuidanceV1.primaryInstruction(maneuver(type = "fork", modifier = "left", roadName = "", roadRef = "")))
        assertEquals("Ta påkjøringsrampen mot E39", NavigationGuidanceV1.primaryInstruction(maneuver(type = "on_ramp", modifier = "right", roadName = "E39", roadRef = "")))
    }

    @Test
    fun `dedupe key includes maneuver and phase`() {
        val a = NavigationGuidanceV1.cueFor(maneuver(id = "a"), 200.0, 20.0)!!
        val b = NavigationGuidanceV1.cueFor(maneuver(id = "b"), 200.0, 20.0)!!
        assertTrue(a.dedupeKey != b.dedupeKey)
        assertEquals("a:approach", a.dedupeKey)
    }
}
