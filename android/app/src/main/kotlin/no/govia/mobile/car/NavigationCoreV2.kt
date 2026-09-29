package no.govia.mobile.car

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

enum class CarGpsQuality { UNKNOWN, GOOD, DEGRADED, POOR }
enum class CarOffRouteState { ON_ROUTE, SUSPECT, OFF_ROUTE }
enum class CarArrivalState { NAVIGATING, APPROACHING, ARRIVED }

data class CarNavigationFix(
    val lat: Double,
    val lon: Double,
    val speedMetersPerSecond: Double,
    val headingDegrees: Double,
    val accuracyMeters: Double,
    val timestampMillis: Long,
)

data class CarAnchoredManeuver(
    val maneuver: CarManeuver,
    val shapeIndex: Int,
    val routeProgressMeters: Double,
)

data class CarNavigationRoute(
    val stageId: String,
    val routeId: String,
    val destinationName: String,
    val transport: String,
    val geometry: List<CarPoint>,
    val maneuvers: List<CarAnchoredManeuver>,
    val distanceMeters: Int,
    val durationSeconds: Int,
    val routeProfile: String,
    val routePreferences: CarRoutePreferences,
) {
    val guidanceReady: Boolean get() = geometry.size >= 2 && maneuvers.isNotEmpty()

    companion object {
        fun fromStage(stage: CarStage): CarNavigationRoute {
            val cumulative = NavigationCoreV2.cumulativeDistances(stage.geometry)
            var previousIndex = 0
            val anchored = stage.maneuvers.sortedBy { it.sequence }.map { maneuver ->
                val anchor = NavigationCoreV2.anchorManeuver(
                    maneuver = maneuver,
                    geometry = stage.geometry,
                    cumulative = cumulative,
                    startIndex = previousIndex,
                )
                previousIndex = max(previousIndex, anchor.first)
                CarAnchoredManeuver(maneuver, anchor.first, anchor.second)
            }
            return CarNavigationRoute(
                stageId = stage.id,
                routeId = stage.id,
                destinationName = stage.end,
                transport = stage.transport,
                geometry = stage.geometry,
                maneuvers = anchored,
                distanceMeters = stage.distanceMeters,
                durationSeconds = stage.durationSeconds,
                routeProfile = stage.routeProfile,
                routePreferences = stage.routePreferences,
            )
        }
    }
}

data class CarNavigationSessionState(
    val route: CarNavigationRoute,
    val currentFix: CarNavigationFix?,
    val matchedPoint: CarPoint?,
    val matchedSegmentIndex: Int,
    val progressMeters: Double,
    val remainingMeters: Double,
    val remainingSeconds: Long,
    val offRouteDistanceMeters: Double,
    val offRouteState: CarOffRouteState,
    val arrivalState: CarArrivalState,
    val gpsQuality: CarGpsQuality,
    val currentManeuver: CarManeuver?,
    val nextManeuver: CarManeuver?,
    val distanceToManeuverMeters: Double?,
) {
    val arrived: Boolean get() = arrivalState == CarArrivalState.ARRIVED
    val rerouteRequired: Boolean get() = offRouteState == CarOffRouteState.OFF_ROUTE && !arrived
}

/**
 * Navigation Core v2. One instance owns exactly one active Stage/route.
 * All progress, matching, ETA, off-route, maneuver and arrival state is derived here.
 */
class NavigationCoreV2(route: CarNavigationRoute) {
    var route: CarNavigationRoute = route
        private set
    var state: CarNavigationSessionState? = null
        private set

    private var cumulative = cumulativeDistances(route.geometry)
    private var progressMeters = 0.0
    private var matchedSegmentIndex = 0
    private var maneuverIndex = 0
    private var offRouteFixes = 0
    private var arrivalFixes = 0
    private var smoothedMovingSpeed: Double? = null
    private var firstFixAt: Long? = null
    private var lastAcceptedFixAt: Long? = null
    private var firstProgressMeters = 0.0

    fun replaceRoute(next: CarNavigationRoute) {
        route = next
        cumulative = cumulativeDistances(next.geometry)
        progressMeters = 0.0
        matchedSegmentIndex = 0
        maneuverIndex = 0
        offRouteFixes = 0
        arrivalFixes = 0
        smoothedMovingSpeed = null
        firstFixAt = null
        lastAcceptedFixAt = null
        firstProgressMeters = 0.0
        state = null
    }

    fun update(fix: CarNavigationFix): CarNavigationSessionState {
        if (route.geometry.size < 2 || cumulative.size != route.geometry.size) {
            return emptyState(fix).also { state = it }
        }
        val gpsQuality = gpsQuality(fix.accuracyMeters)
        if (gpsQuality == CarGpsQuality.POOR && state != null) {
            return state!!.copy(currentFix = fix, gpsQuality = gpsQuality).also { state = it }
        }

        val projection = bestProjection(fix)
        val elapsedSeconds = lastAcceptedFixAt?.let { max(0.2, (fix.timestampMillis - it) / 1000.0) } ?: 1.0
        val speed = fix.speedMetersPerSecond.takeIf { it.isFinite() }?.coerceIn(0.0, 80.0) ?: 0.0
        val maxForwardJump = max(120.0, speed * elapsedSeconds * 4 + max(80.0, fix.accuracyMeters * 2))
        val backwardsAllowance = max(35.0, min(75.0, fix.accuracyMeters * 1.25))
        if (state == null ||
            (projection.progressMeters >= progressMeters - backwardsAllowance &&
                projection.progressMeters <= progressMeters + maxForwardJump)
        ) {
            progressMeters = max(progressMeters, projection.progressMeters)
            matchedSegmentIndex = projection.segmentIndex
            lastAcceptedFixAt = fix.timestampMillis
        }

        if (firstFixAt == null) firstFixAt = fix.timestampMillis
        if (firstProgressMeters == 0.0) firstProgressMeters = progressMeters
        if (speed >= 1.5) smoothedMovingSpeed = smoothedMovingSpeed?.let { it * 0.82 + speed * 0.18 } ?: speed

        val routeLength = cumulative.last()
        val remaining = max(0.0, routeLength - progressMeters)
        val offRouteThreshold = max(70.0, min(160.0, fix.accuracyMeters * 2))
        if (projection.distanceMeters > offRouteThreshold) offRouteFixes++ else offRouteFixes = 0
        val offRouteState = when {
            offRouteFixes >= 3 -> CarOffRouteState.OFF_ROUTE
            offRouteFixes > 0 -> CarOffRouteState.SUSPECT
            else -> CarOffRouteState.ON_ROUTE
        }

        val destination = route.geometry.last()
        val destinationDistance = haversine(fix.lat, fix.lon, destination.lat, destination.lon)
        val accuracy = if (fix.accuracyMeters.isFinite()) fix.accuracyMeters.coerceIn(0.0, 250.0) else 250.0
        val preciseRadius = max(25.0, min(45.0, accuracy * 1.25))
        val credibleArrival = destinationDistance <= preciseRadius ||
            (destinationDistance <= 55.0 && speed <= 5.0 && accuracy <= 35.0)
        if (credibleArrival) arrivalFixes++ else if (destinationDistance > 80.0) arrivalFixes = 0
        val arrivalState = when {
            arrivalFixes >= 3 -> CarArrivalState.ARRIVED
            destinationDistance <= 180.0 -> CarArrivalState.APPROACHING
            else -> CarArrivalState.NAVIGATING
        }

        advanceManeuver()
        val currentAnchored = route.maneuvers.getOrNull(maneuverIndex)
        val current = currentAnchored?.maneuver
        val next = route.maneuvers.getOrNull(maneuverIndex + 1)?.maneuver
        val distanceToManeuver = currentAnchored?.let { max(0.0, it.routeProgressMeters - progressMeters) }
        val matchedPoint = if (projection.distanceMeters <= max(140.0, accuracy * 2.5)) projection.point else null
        val result = CarNavigationSessionState(
            route = route,
            currentFix = fix,
            matchedPoint = matchedPoint,
            matchedSegmentIndex = matchedSegmentIndex,
            progressMeters = progressMeters,
            remainingMeters = if (arrivalState == CarArrivalState.ARRIVED) 0.0 else remaining,
            remainingSeconds = if (arrivalState == CarArrivalState.ARRIVED) 0L else estimateRemainingSeconds(remaining, fix.timestampMillis),
            offRouteDistanceMeters = projection.distanceMeters,
            offRouteState = if (arrivalState == CarArrivalState.ARRIVED) CarOffRouteState.ON_ROUTE else offRouteState,
            arrivalState = arrivalState,
            gpsQuality = gpsQuality,
            currentManeuver = if (arrivalState == CarArrivalState.ARRIVED) null else current,
            nextManeuver = if (arrivalState == CarArrivalState.ARRIVED) null else next,
            distanceToManeuverMeters = if (arrivalState == CarArrivalState.ARRIVED) null else distanceToManeuver,
        )
        state = result
        return result
    }

    private fun emptyState(fix: CarNavigationFix) = CarNavigationSessionState(
        route = route,
        currentFix = fix,
        matchedPoint = null,
        matchedSegmentIndex = 0,
        progressMeters = 0.0,
        remainingMeters = route.distanceMeters.toDouble(),
        remainingSeconds = route.durationSeconds.toLong(),
        offRouteDistanceMeters = 0.0,
        offRouteState = CarOffRouteState.ON_ROUTE,
        arrivalState = CarArrivalState.NAVIGATING,
        gpsQuality = gpsQuality(fix.accuracyMeters),
        currentManeuver = route.maneuvers.firstOrNull()?.maneuver,
        nextManeuver = route.maneuvers.getOrNull(1)?.maneuver,
        distanceToManeuverMeters = route.maneuvers.firstOrNull()?.routeProgressMeters,
    )

    private fun advanceManeuver() {
        while (maneuverIndex < route.maneuvers.lastIndex &&
            route.maneuvers[maneuverIndex].routeProgressMeters <= progressMeters + 20.0
        ) maneuverIndex++
    }

    private fun estimateRemainingSeconds(remaining: Double, now: Long): Long {
        if (remaining <= 0.0) return 0L
        val totalDistance = max(1.0, cumulative.lastOrNull() ?: route.distanceMeters.toDouble())
        val baselineSeconds = max(1.0, route.durationSeconds.toDouble())
        val baselineSpeed = totalDistance / baselineSeconds
        val observedSpeed = firstFixAt?.let { started ->
            val elapsed = (now - started).coerceAtLeast(0L) / 1000.0
            val progressed = max(0.0, progressMeters - firstProgressMeters)
            if (elapsed >= 90.0 && progressed >= 500.0) progressed / elapsed else null
        }
        var effectiveSpeed = baselineSpeed
        observedSpeed?.takeIf { it >= 1.5 }?.let { effectiveSpeed = baselineSpeed * 0.45 + it * 0.55 }
        smoothedMovingSpeed?.takeIf { it >= 1.5 }?.let { effectiveSpeed = effectiveSpeed * 0.75 + it * 0.25 }
        effectiveSpeed = effectiveSpeed.coerceIn(baselineSpeed * 0.45, baselineSpeed * 1.35)
        return (remaining / max(0.8, effectiveSpeed)).toLong().coerceAtLeast(0L)
    }

    private fun bestProjection(fix: CarNavigationFix): RouteProjection {
        val start = max(0, matchedSegmentIndex - 18)
        val end = min(route.geometry.size - 2, matchedSegmentIndex + 90)
        var best = scanProjection(fix, start, end)
        if (best.distanceMeters > 180.0 || state == null) {
            val global = scanProjection(fix, 0, route.geometry.size - 2)
            if (global.score < best.score) best = global
        }
        return best
    }

    private fun scanProjection(fix: CarNavigationFix, start: Int, end: Int): RouteProjection {
        var best = RouteProjection(start, cumulative[start], Double.MAX_VALUE, route.geometry[start], Double.MAX_VALUE)
        val hasHeading = fix.speedMetersPerSecond >= 1.5 && fix.headingDegrees.isFinite() && fix.headingDegrees >= 0.0
        for (i in start..end) {
            val a = route.geometry[i]
            val b = route.geometry[i + 1]
            val projection = project(fix.lat, fix.lon, a, b)
            val progress = cumulative[i] + projection.segmentMeters * projection.t
            val continuityPenalty = if (state == null) 0.0 else min(160.0, abs(i - matchedSegmentIndex) * 1.8)
            val backwardPenalty = if (progress < progressMeters - 45.0) min(300.0, (progressMeters - progress) * 0.55) else 0.0
            val headingPenalty = if (hasHeading) headingDelta(fix.headingDegrees, bearing(a, b)) * 0.55 else 0.0
            val score = projection.distanceMeters + continuityPenalty + backwardPenalty + headingPenalty
            if (score < best.score) best = RouteProjection(i, progress, projection.distanceMeters, projection.point, score)
        }
        return best
    }

    private fun gpsQuality(accuracy: Double) = when {
        !accuracy.isFinite() || accuracy <= 0.0 -> CarGpsQuality.UNKNOWN
        accuracy <= 25.0 -> CarGpsQuality.GOOD
        accuracy <= 80.0 -> CarGpsQuality.DEGRADED
        else -> CarGpsQuality.POOR
    }

    private data class RouteProjection(
        val segmentIndex: Int,
        val progressMeters: Double,
        val distanceMeters: Double,
        val point: CarPoint,
        val score: Double,
    )

    companion object {
        internal fun cumulativeDistances(points: List<CarPoint>): List<Double> {
            if (points.isEmpty()) return emptyList()
            val out = MutableList(points.size) { 0.0 }
            for (i in 1 until points.size) out[i] = out[i - 1] + haversine(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon)
            return out
        }

        internal fun anchorManeuver(
            maneuver: CarManeuver,
            geometry: List<CarPoint>,
            cumulative: List<Double>,
            startIndex: Int,
        ): Pair<Int, Double> {
            val loc = maneuver.location
            if (loc == null || geometry.size < 2 || cumulative.size != geometry.size) {
                return 0 to maneuver.distanceFromStartMeters.toDouble()
            }
            var bestIndex = startIndex.coerceIn(0, geometry.size - 2)
            var bestProgress = cumulative[bestIndex]
            var bestDistance = Double.MAX_VALUE
            for (i in bestIndex until geometry.lastIndex) {
                val projection = project(loc.lat, loc.lon, geometry[i], geometry[i + 1])
                if (projection.distanceMeters < bestDistance) {
                    bestDistance = projection.distanceMeters
                    bestIndex = i
                    bestProgress = cumulative[i] + projection.segmentMeters * projection.t
                }
            }
            return bestIndex to bestProgress
        }

        private data class SegmentProjection(val t: Double, val distanceMeters: Double, val segmentMeters: Double, val point: CarPoint)

        private fun project(lat: Double, lon: Double, a: CarPoint, b: CarPoint): SegmentProjection {
            val scale = cos(Math.toRadians(lat)).coerceAtLeast(0.2)
            val ax = a.lon * scale
            val ay = a.lat
            val bx = b.lon * scale
            val by = b.lat
            val px = lon * scale
            val py = lat
            val dx = bx - ax
            val dy = by - ay
            val length2 = dx * dx + dy * dy
            val t = if (length2 <= 1e-14) 0.0 else (((px - ax) * dx + (py - ay) * dy) / length2).coerceIn(0.0, 1.0)
            val point = CarPoint(a.lon + (b.lon - a.lon) * t, a.lat + (b.lat - a.lat) * t)
            return SegmentProjection(t, haversine(lat, lon, point.lat, point.lon), haversine(a.lat, a.lon, b.lat, b.lon), point)
        }

        private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
            val r = 6_371_000.0
            val p1 = Math.toRadians(lat1)
            val p2 = Math.toRadians(lat2)
            val dp = Math.toRadians(lat2 - lat1)
            val dl = Math.toRadians(lon2 - lon1)
            val a = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
            return 2 * r * atan2(sqrt(a), sqrt(1 - a))
        }

        private fun bearing(from: CarPoint, to: CarPoint): Double {
            val lat1 = Math.toRadians(from.lat)
            val lat2 = Math.toRadians(to.lat)
            val dLon = Math.toRadians(to.lon - from.lon)
            val y = sin(dLon) * cos(lat2)
            val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
            return ((Math.toDegrees(atan2(y, x)) % 360.0) + 360.0) % 360.0
        }

        private fun headingDelta(a: Double, b: Double): Double = abs(((a - b + 540.0) % 360.0) - 180.0)
    }
}
