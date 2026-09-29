package no.govia.mobile.car

fun main() {
    val m = CarManeuver(
        id = "m1", sequence = 0, type = "roundabout", modifier = "", instruction = "Roundabout",
        roadName = "Bergen", roadRef = "E39", distanceMeters = 0, distanceFromStartMeters = 500,
        exit = 3, location = CarPoint(5.0, 60.0),
    )
    check(NavigationGuidanceV1.primaryInstruction(m) == "I rundkjøringen, ta tredje avkjøring mot E39 Bergen")
    check(NavigationGuidanceV1.phaseFor(50.0, 80.0 / 3.6) == CarGuidancePhase.NOW)
    check(NavigationGuidanceV1.thresholds(110.0 / 3.6).prepareMeters > NavigationGuidanceV1.thresholds(30.0 / 3.6).prepareMeters)
    val roundaboutNoExit = m.copy(id = "roundabout-no-exit", exit = null, modifier = "slight_right", instruction = "Sving svakt til høyre")
    check(NavigationGuidanceV1.primaryInstruction(roundaboutNoExit).startsWith("Kjør inn i rundkjøringen"))

    val motorwayExit = m.copy(id = "motorway-exit", type = "off_ramp", exit = null, modifier = "right", roadName = "Fjøsangerveien", roadRef = "E39")
    check(NavigationGuidanceV1.primaryInstruction(motorwayExit) == "Ta neste avkjøring mot E39 Fjøsangerveien")

    println("Navigation Guidance v1 Kotlin smoke: PASS")
}
