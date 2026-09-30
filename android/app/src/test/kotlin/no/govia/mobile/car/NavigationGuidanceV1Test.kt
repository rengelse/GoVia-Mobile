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
    fun `time oriented thresholds move earlier with speed`() {
        val city = NavigationGuidanceV1.thresholds(30.0 / 3.6)
        val motorway = NavigationGuidanceV1.thresholds(110.0 / 3.6)
        assertTrue(motorway.prepareMeters > city.prepareMeters)
        assertEquals((30.0 / 3.6) * 22.0, city.approachMeters, 0.01)
        assertEquals(550.0, motorway.approachMeters, 0.01)
        assertEquals(90.0, motorway.nowMeters, 0.01)
    }

    @Test
    fun `ordinary urban turn skips prepare`() {
        val speed = 50.0 / 3.6
        assertEquals(null, NavigationGuidanceV1.cueFor(maneuver(), 700.0, speed))
        assertEquals(CarGuidancePhase.APPROACH, NavigationGuidanceV1.cueFor(maneuver(), 250.0, speed)?.phase)
        assertEquals(CarGuidancePhase.NOW, NavigationGuidanceV1.cueFor(maneuver(), 60.0, speed)?.phase)
    }

    @Test
    fun `complex high speed maneuver may use prepare`() {
        val cue = NavigationGuidanceV1.cueFor(maneuver(type = "off_ramp", modifier = "right"), 1400.0, 90.0 / 3.6)
        assertEquals(CarGuidancePhase.PREPARE, cue?.phase)
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
    fun `normalized geometry guidance remains voice actionable`() {
        val cue = NavigationGuidanceV1.cueFor(
            maneuver(type = "turn", modifier = "right", source = "geometry", confidence = 0.7),
            120.0,
            15.0,
        )
        assertTrue(cue != null)
        assertEquals("Ta til høyre mot E39 Bergen sentrum", cue?.primaryText)
    }

    @Test
    fun `geometry roundabout and exit remain voice actionable`() {
        assertTrue(NavigationGuidanceV1.cueFor(maneuver(type = "roundabout", modifier = "", source = "geometry", exit = 2), 120.0, 15.0) != null)
        assertTrue(NavigationGuidanceV1.cueFor(maneuver(type = "off_ramp", modifier = "right", source = "geometry"), 120.0, 15.0) != null)
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
    fun `slight ordinary turn is silent because it can be road curvature`() {
        assertEquals(
            null,
            NavigationGuidanceV1.cueFor(
                maneuver(type = "turn", modifier = "slight_right", source = "geometry"),
                120.0,
                15.0,
            ),
        )
    }

    @Test
    fun `real decision points remain voice actionable`() {
        assertTrue(NavigationGuidanceV1.cueFor(maneuver(type = "turn", modifier = "right"), 120.0, 15.0) != null)
        assertTrue(NavigationGuidanceV1.cueFor(maneuver(type = "end_of_road", modifier = "left"), 120.0, 15.0) != null)
        assertTrue(NavigationGuidanceV1.cueFor(maneuver(type = "roundabout", modifier = "", exit = 2), 120.0, 15.0) != null)
        assertTrue(NavigationGuidanceV1.cueFor(maneuver(type = "off_ramp", modifier = "right"), 120.0, 15.0) != null)
    }

    @Test
    fun `dedupe key includes maneuver and phase`() {
        val a = NavigationGuidanceV1.cueFor(maneuver(id = "a"), 200.0, 20.0)!!
        val b = NavigationGuidanceV1.cueFor(maneuver(id = "b"), 200.0, 20.0)!!
        assertTrue(a.dedupeKey != b.dedupeKey)
        assertEquals("a:approach", a.dedupeKey)
    }
}
