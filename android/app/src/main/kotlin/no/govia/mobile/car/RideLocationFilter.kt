package no.govia.mobile.car

import kotlin.math.max
import kotlin.math.min

/** Pure recording filter. Keeps bad GPS/network fixes out of the persisted ride polyline. */
internal data class RideLocationSample(
    val provider: String,
    val latitude: Double,
    val longitude: Double,
    val timeMs: Long,
    val accuracyMeters: Float,
)

internal class RideLocationFilter(
    private val nowMs: () -> Long = { System.currentTimeMillis() },
) {
    private var lastAccepted: RideLocationSample? = null
    private var lastAcceptedGpsTimeMs: Long = Long.MIN_VALUE

    fun reset() {
        lastAccepted = null
        lastAcceptedGpsTimeMs = Long.MIN_VALUE
    }

    fun accept(sample: RideLocationSample): Boolean {
        if (!sample.latitude.isFinite() || !sample.longitude.isFinite()) return false
        if (sample.latitude !in -90.0..90.0 || sample.longitude !in -180.0..180.0) return false
        if (!sample.accuracyMeters.isFinite() || sample.accuracyMeters <= 0f) return false

        val provider = sample.provider.lowercase()
        val isGps = provider == "gps"
        val isNetwork = provider == "network"
        if (!isGps && !isNetwork) return false

        val ageMs = nowMs() - sample.timeMs
        if (ageMs < -2_000L || ageMs > MAX_FIX_AGE_MS) return false

        val maxAccuracy = if (isGps) MAX_GPS_ACCURACY_METERS else MAX_NETWORK_ACCURACY_METERS
        if (sample.accuracyMeters > maxAccuracy) return false

        if (isNetwork && lastAcceptedGpsTimeMs != Long.MIN_VALUE && sample.timeMs - lastAcceptedGpsTimeMs <= NETWORK_SUPPRESSION_AFTER_GPS_MS) {
            return false
        }

        val previous = lastAccepted
        if (previous != null) {
            val dtMs = sample.timeMs - previous.timeMs
            if (dtMs <= 0L || dtMs < MIN_SAMPLE_INTERVAL_MS) return false
            val distance = distanceMeters(previous.latitude, previous.longitude, sample.latitude, sample.longitude)
            val precisionFloor = max(MIN_MOVE_METERS, min(MAX_NOISE_FLOOR_METERS, ((previous.accuracyMeters + sample.accuracyMeters) * 0.25f).toDouble()))
            if (distance < precisionFloor) return false

            val seconds = dtMs / 1000.0
            val uncertainty = max(previous.accuracyMeters, sample.accuracyMeters).toDouble()
            val maxPlausibleDistance = MAX_PLAUSIBLE_SPEED_MPS * seconds + uncertainty * 2.0 + JUMP_MARGIN_METERS
            if (distance > maxPlausibleDistance) return false
        }

        lastAccepted = sample
        if (isGps) lastAcceptedGpsTimeMs = sample.timeMs
        return true
    }

    companion object {
        private const val MAX_FIX_AGE_MS = 12_000L
        private const val MIN_SAMPLE_INTERVAL_MS = 700L
        private const val NETWORK_SUPPRESSION_AFTER_GPS_MS = 15_000L
        private const val MAX_GPS_ACCURACY_METERS = 35f
        private const val MAX_NETWORK_ACCURACY_METERS = 25f
        private const val MIN_MOVE_METERS = 5.0
        private const val MAX_NOISE_FLOOR_METERS = 15.0
        private const val MAX_PLAUSIBLE_SPEED_MPS = 65.0 // 234 km/h plus accuracy margin
        private const val JUMP_MARGIN_METERS = 20.0
    }
}

private fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val radius = 6_371_000.0
    val p1 = Math.toRadians(lat1)
    val p2 = Math.toRadians(lat2)
    val dp = Math.toRadians(lat2 - lat1)
    val dl = Math.toRadians(lon2 - lon1)
    val a = kotlin.math.sin(dp / 2) * kotlin.math.sin(dp / 2) +
        kotlin.math.cos(p1) * kotlin.math.cos(p2) * kotlin.math.sin(dl / 2) * kotlin.math.sin(dl / 2)
    return 2 * radius * kotlin.math.atan2(kotlin.math.sqrt(a), kotlin.math.sqrt(1 - a))
}
