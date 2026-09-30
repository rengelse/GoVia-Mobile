package no.govia.mobile.ferrostar.poc

/**
 * Deliberately small PoC-only model.
 *
 * This is NOT a third GoVia navigation runtime. It models only the provider-anchored data that
 * must cross the GoVia server -> navigation-core boundary if Ferrostar is adopted.
 */
data class CanonicalPoint(val lon: Double, val lat: Double)

data class CanonicalManeuver(
    val id: String,
    val type: String,
    val modifier: String,
    val instruction: String,
    val roadName: String = "",
    val roadRef: String = "",
    val routeOffsetMeters: Double,
    /** Provider-authoritative path/shape index. Required: no nearest-geometry guessing here. */
    val shapeIndex: Int,
    val exitNumber: Int? = null,
)

data class CanonicalSpeedLimitSection(
    val startPathIndex: Int,
    val endPathIndex: Int,
    val speedLimitKph: Int,
)

data class CanonicalRoute(
    val geometry: List<CanonicalPoint>,
    val distanceMeters: Double,
    val durationSeconds: Double,
    val maneuvers: List<CanonicalManeuver>,
    val speedLimits: List<CanonicalSpeedLimitSection>,
) {
    init {
        require(geometry.size >= 2) { "Route requires at least two geometry points" }
        require(distanceMeters > 0) { "Route distance must be positive" }
        require(maneuvers.isNotEmpty()) { "Canonical guidance is mandatory for the PoC" }
        require(maneuvers.zipWithNext().all { (a, b) -> a.shapeIndex <= b.shapeIndex }) {
            "Maneuvers must be ordered by provider shape index"
        }
        require(maneuvers.all { it.shapeIndex in geometry.indices }) {
            "Every maneuver must have a valid provider shape index"
        }
    }
}
