package no.govia.mobile.car

data class CarPoint(val lon: Double, val lat: Double)

data class CarManeuver(
    val id: String,
    val sequence: Int,
    val instruction: String,
    val roadName: String,
    val distanceMeters: Int,
    val distanceFromStartMeters: Int,
    val location: CarPoint?
)

data class CarStage(
    val id: String,
    val day: Int,
    val order: Int,
    val start: String,
    val end: String,
    val transport: String,
    val distanceMeters: Int,
    val durationSeconds: Int,
    val geometry: List<CarPoint>,
    val maneuvers: List<CarManeuver>
)

data class CarTrip(
    val id: String,
    val name: String,
    val start: String,
    val end: String,
    val status: String,
    val stages: List<CarStage>
) {
    val totalDistanceMeters: Int get() = stages.sumOf { it.distanceMeters }
    val totalDurationSeconds: Int get() = stages.sumOf { it.durationSeconds }
}

data class CarPoi(
    val id: String,
    val name: String,
    val category: String,
    val distanceMeters: Int
)

data class CarState(
    val activeTripId: String?,
    val voiceEnabled: Boolean,
    val trips: List<CarTrip>,
    val pois: List<CarPoi>
)
