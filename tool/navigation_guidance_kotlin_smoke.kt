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
    println("Navigation Guidance v1 Kotlin smoke: PASS")
}
