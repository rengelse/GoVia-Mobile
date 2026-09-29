package no.govia.mobile.car

import org.json.JSONObject
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/** Parses provider speed-limit sections without coupling navigation UI to one backend schema. */
object CarSpeedLimitParser {
    fun parse(route: JSONObject, geometry: List<CarPoint>): List<CarSpeedLimitSection> {
        val rows = mutableListOf<JSONObject>()
        listOf("speedLimits", "speedLimitSections", "speed_limit_sections").forEach { key ->
            val array = route.optJSONArray(key) ?: return@forEach
            for (i in 0 until array.length()) array.optJSONObject(i)?.let(rows::add)
        }
        route.optJSONArray("sections")?.let { array ->
            for (i in 0 until array.length()) {
                val row = array.optJSONObject(i) ?: continue
                val type = row.optString("type", row.optString("sectionType", row.optString("section_type"))).lowercase()
                if (type.contains("speed") && type.contains("limit")) rows.add(row)
            }
        } ?: route.optJSONObject("sections")?.let { sections ->
            val nested = sections.optJSONArray("speedLimitSections") ?: sections.optJSONArray("speedLimits")
            if (nested != null) for (i in 0 until nested.length()) nested.optJSONObject(i)?.let(rows::add)
        }
        if (rows.isEmpty()) return emptyList()

        val cumulative = cumulativeDistances(geometry)
        return rows.mapNotNull { row ->
            val speed = speedKph(row) ?: return@mapNotNull null
            if (speed !in 1..200) return@mapNotNull null
            val startIndex = row.optInt("startPointIndex", -1)
            val endIndex = row.optInt("endPointIndex", -1)
            val start = distanceMeters(row.opt("startDistanceMeters"))
                ?: distanceMeters(row.opt("routeOffset"))
                ?: distanceMeters(row.opt("offset"))
                ?: cumulative.getOrNull(startIndex)
                ?: return@mapNotNull null
            val end = distanceMeters(row.opt("endDistanceMeters"))
                ?: distanceMeters(row.opt("endOffset"))
                ?: cumulative.getOrNull(endIndex)
                ?: distanceMeters(row.opt("length"))?.let { start + it }
                ?: return@mapNotNull null
            if (start < 0.0 || end <= start) return@mapNotNull null
            CarSpeedLimitSection(
                startDistanceMeters = start.roundToInt(),
                endDistanceMeters = end.roundToInt(),
                speedLimitKph = speed,
                source = row.optString("source", row.optString("provider", "provider")),
                confidence = row.optDouble("confidence", 1.0).coerceIn(0.0, 1.0),
            )
        }.sortedBy { it.startDistanceMeters }
    }

    private fun distanceMeters(raw: Any?): Double? = when (raw) {
        is Number -> raw.toDouble()
        is JSONObject -> listOf("meters", "meter", "value", "distance")
            .firstNotNullOfOrNull { key -> (raw.opt(key) as? Number)?.toDouble() }
        else -> null
    }

    private fun speedKph(row: JSONObject): Int? {
        val raw = row.opt("speedLimitKph")
            ?: row.opt("speedLimitInKmh")
            ?: row.opt("speed_limit_kph")
            ?: row.opt("speedLimit")
        val value = when (raw) {
            is Number -> raw.toDouble()
            is JSONObject -> {
                val direct = listOf("kilometersPerHour", "kmh", "kph", "value")
                    .firstNotNullOfOrNull { key -> (raw.opt(key) as? Number)?.toDouble() }
                direct ?: (raw.opt("metersPerSecond") as? Number)?.toDouble()?.times(3.6)
            }
            else -> null
        }
        return value?.roundToInt()
    }

    private fun cumulativeDistances(points: List<CarPoint>): List<Double> {
        if (points.isEmpty()) return emptyList()
        val result = MutableList(points.size) { 0.0 }
        for (i in 1 until points.size) result[i] = result[i - 1] + distance(points[i - 1], points[i])
        return result
    }

    private fun distance(a: CarPoint, b: CarPoint): Double {
        val radius = 6_371_000.0
        val p1 = Math.toRadians(a.lat)
        val p2 = Math.toRadians(b.lat)
        val dp = Math.toRadians(b.lat - a.lat)
        val dl = Math.toRadians(b.lon - a.lon)
        val h = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * radius * atan2(sqrt(h), sqrt(1 - h))
    }
}
