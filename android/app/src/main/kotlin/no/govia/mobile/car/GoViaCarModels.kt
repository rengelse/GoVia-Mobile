package no.govia.mobile.car

data class CarPoint(val lon: Double, val lat: Double)

data class CarSpeedLimitSection(
    val startDistanceMeters: Int,
    val endDistanceMeters: Int,
    val speedLimitKph: Int,
    val startPathIndex: Int? = null,
    val endPathIndex: Int? = null,
    val source: String = "provider",
    val confidence: Double = 1.0,
)

data class CarManeuver(
    val id: String,
    val sequence: Int,
    val type: String = "turn",
    val modifier: String = "",
    val instruction: String,
    val roadName: String,
    val roadRef: String = "",
    val distanceMeters: Int,
    val durationSeconds: Int = 0,
    val distanceFromStartMeters: Int,
    val shapeIndex: Int? = null,
    val exit: Int? = null,
    val source: String = "none",
    val confidence: Double = 0.0,
    val location: CarPoint?,
)

data class CarWaypoint(
    val id: String,
    val name: String,
    val kind: String,
    val category: String = "",
    val note: String = "",
    val distanceFromStartMeters: Int = 0,
    val location: CarPoint? = null,
)

data class CarRoutePreferences(
    val avoidMotorways: Boolean = false,
    val avoidTolls: Boolean = false,
    val avoidFerries: Boolean = false,
    val avoidUnpaved: Boolean = false,
    val avoidCities: Boolean = false,
    val preferScenic: Boolean = false,
    val preferCoastal: Boolean = false,
    val preferMountains: Boolean = false,
)

data class CarStage(
    val id: String,
    val day: Int,
    val order: Int,
    val start: String,
    val end: String,
    val transport: String,
    val name: String = "",
    val status: String = "planned",
    val routeId: String = "",
    val waypoints: List<CarWaypoint> = emptyList(),
    val distanceMeters: Int,
    val durationSeconds: Int,
    val geometry: List<CarPoint>,
    val maneuvers: List<CarManeuver>,
    val speedLimitSections: List<CarSpeedLimitSection> = emptyList(),
    val routeProfile: String = "fastest",
    val routePreferences: CarRoutePreferences = CarRoutePreferences(),
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
    val themeMode: String,
    val apiBaseUrl: String,
    val accessToken: String?,
    val trips: List<CarTrip>,
    val pois: List<CarPoi>
)
