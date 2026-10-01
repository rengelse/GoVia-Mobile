package no.govia.mobile.car

enum class CarGpsQuality { UNKNOWN, GOOD, DEGRADED, POOR }
enum class CarOffRouteState { ON_ROUTE, SUSPECT, OFF_ROUTE }

data class CarNavigationFix(
    val lat: Double,
    val lon: Double,
    val speedMetersPerSecond: Double,
    val headingDegrees: Double,
    val accuracyMeters: Double,
    val timestampMillis: Long,
)

/** Minimal process-recovery snapshot. Route progress is re-derived by Ferrostar from this fix. */
data class CarNavigationRuntimeSnapshot(
    val currentFix: CarNavigationFix?,
    val progressMeters: Double,
    val arrived: Boolean,
)
