package no.govia.mobile.car

import android.content.Context
import no.govia.mobile.CarBridgeStore
import org.json.JSONArray
import org.json.JSONObject

data class CarPersistedNavigationSession(
    val tripId: String,
    val stage: CarStage,
    val snapshot: CarNavigationSessionSnapshot,
    val guidanceKeys: Set<String> = emptySet(),
)

class GoViaCarRepository(context: Context) {
    private val prefs = context.getSharedPreferences("govia_car_runtime", Context.MODE_PRIVATE)
    private val bridge = CarBridgeStore(context.applicationContext)

    fun readState(): CarState {
        val raw = bridge.readState() ?: return CarState(null, true, "system", "https://govia.no", null, emptyList(), emptyList())
        return try {
            val root = JSONObject(raw)
            CarState(
                activeTripId = root.optString("activeTripId").ifBlank { null },
                voiceEnabled = root.optBoolean("voiceEnabled", true),
                themeMode = root.optString("themeMode", "system").takeIf { it in setOf("system", "light", "dark") } ?: "system",
                apiBaseUrl = root.optString("apiBaseUrl", "https://govia.no").trimEnd('/').ifBlank { "https://govia.no" },
                accessToken = root.optString("accessToken").takeIf { it.isNotBlank() },
                trips = root.optJSONArray("trips").toTrips(),
                pois = root.optJSONArray("pois").toPois()
            )
        } catch (_: Exception) {
            CarState(null, true, "system", "https://govia.no", null, emptyList(), emptyList())
        }
    }

    fun setSelectedTripId(id: String?) {
        prefs.edit().putString("car_selected_trip_id", id).apply()
    }

    fun selectedTripId(): String? = prefs.getString("car_selected_trip_id", null)

    fun setActiveStageId(id: String?) {
        prefs.edit().putString("car_active_stage_id", id).apply()
    }

    fun activeStageId(): String? = prefs.getString("car_active_stage_id", null)

    fun persistNavigationRoute(
        tripId: String,
        stage: CarStage,
        snapshot: CarNavigationSessionSnapshot,
        guidanceKeys: Set<String> = emptySet(),
    ) {
        val routeJson = JSONObject()
            .put("tripId", tripId)
            .put("stage", stage.toJson())
        val snapshotJson = snapshotJson(tripId, stage.id, stage.routeId, snapshot, guidanceKeys)
        prefs.edit()
            .putString("car_navigation_route_v3", routeJson.toString())
            .putString("car_navigation_snapshot_v3", snapshotJson.toString())
            .putString("car_selected_trip_id", tripId)
            .putString("car_active_stage_id", stage.id)
            .apply()
    }

    fun persistNavigationSnapshot(
        tripId: String,
        stageId: String,
        routeId: String,
        snapshot: CarNavigationSessionSnapshot,
        guidanceKeys: Set<String> = emptySet(),
    ) {
        prefs.edit()
            .putString("car_navigation_snapshot_v3", snapshotJson(tripId, stageId, routeId, snapshot, guidanceKeys).toString())
            .apply()
    }

    private fun snapshotJson(
        tripId: String,
        stageId: String,
        routeId: String,
        snapshot: CarNavigationSessionSnapshot,
        guidanceKeys: Set<String> = emptySet(),
    ): JSONObject = JSONObject()
        .put("tripId", tripId)
        .put("stageId", stageId)
        .put("routeId", routeId)
        .put("currentFix", snapshot.currentFix?.let { fix -> JSONObject()
            .put("lat", fix.lat)
            .put("lon", fix.lon)
            .put("speedMetersPerSecond", fix.speedMetersPerSecond)
            .put("headingDegrees", fix.headingDegrees)
            .put("accuracyMeters", fix.accuracyMeters)
            .put("timestampMillis", fix.timestampMillis) })
        .put("progressMeters", snapshot.progressMeters)
        .put("matchedSegmentIndex", snapshot.matchedSegmentIndex)
        .put("maneuverIndex", snapshot.maneuverIndex)
        .put("offRouteFixes", snapshot.offRouteFixes)
        .put("arrivalFixes", snapshot.arrivalFixes)
        .put("smoothedMovingSpeed", snapshot.smoothedMovingSpeed)
        .put("firstFixAt", snapshot.firstFixAt)
        .put("lastAcceptedFixAt", snapshot.lastAcceptedFixAt)
        .put("lastSeenFixAt", snapshot.lastSeenFixAt)
        .put("firstProgressMeters", snapshot.firstProgressMeters)
        .put("rerouteState", snapshot.rerouteState.name)
        .put("guidanceKeys", guidanceKeysJson(guidanceKeys))


    private fun guidanceKeysJson(guidanceKeys: Set<String>): JSONArray {
        val array = JSONArray()
        guidanceKeys.toList().sorted().forEach(array::put)
        return array
    }

    fun persistedNavigationSession(): CarPersistedNavigationSession? {
        val routeRaw = prefs.getString("car_navigation_route_v3", null) ?: return null
        val snapshotRaw = prefs.getString("car_navigation_snapshot_v3", null) ?: return null
        return runCatching {
            val routeRoot = JSONObject(routeRaw)
            val snapshotRoot = JSONObject(snapshotRaw)
            val tripId = routeRoot.getString("tripId")
            val stage = JSONArray().put(routeRoot.getJSONObject("stage")).toStages().single()
            require(snapshotRoot.getString("tripId") == tripId)
            require(snapshotRoot.getString("stageId") == stage.id)
            require(snapshotRoot.getString("routeId") == stage.routeId)
            CarPersistedNavigationSession(
                tripId = tripId,
                stage = stage,
                snapshot = CarNavigationSessionSnapshot(
                    currentFix = snapshotRoot.optJSONObject("currentFix")?.let { fix -> CarNavigationFix(
                        lat = fix.optDouble("lat"),
                        lon = fix.optDouble("lon"),
                        speedMetersPerSecond = fix.optDouble("speedMetersPerSecond"),
                        headingDegrees = fix.optDouble("headingDegrees"),
                        accuracyMeters = fix.optDouble("accuracyMeters", 999.0),
                        timestampMillis = fix.optLong("timestampMillis"),
                    ) },
                    progressMeters = snapshotRoot.optDouble("progressMeters", 0.0),
                    matchedSegmentIndex = snapshotRoot.optInt("matchedSegmentIndex", 0),
                    maneuverIndex = snapshotRoot.optInt("maneuverIndex", 0),
                    offRouteFixes = snapshotRoot.optInt("offRouteFixes", 0),
                    arrivalFixes = snapshotRoot.optInt("arrivalFixes", 0),
                    smoothedMovingSpeed = snapshotRoot.optDouble("smoothedMovingSpeed").takeIf { snapshotRoot.has("smoothedMovingSpeed") && !snapshotRoot.isNull("smoothedMovingSpeed") },
                    firstFixAt = snapshotRoot.optLong("firstFixAt").takeIf { snapshotRoot.has("firstFixAt") && !snapshotRoot.isNull("firstFixAt") },
                    lastAcceptedFixAt = snapshotRoot.optLong("lastAcceptedFixAt").takeIf { snapshotRoot.has("lastAcceptedFixAt") && !snapshotRoot.isNull("lastAcceptedFixAt") },
                    lastSeenFixAt = snapshotRoot.optLong("lastSeenFixAt").takeIf { snapshotRoot.has("lastSeenFixAt") && !snapshotRoot.isNull("lastSeenFixAt") },
                    firstProgressMeters = snapshotRoot.optDouble("firstProgressMeters", 0.0),
                    rerouteState = runCatching { CarRerouteState.valueOf(snapshotRoot.optString("rerouteState", "IDLE")) }.getOrDefault(CarRerouteState.IDLE),
                ),
                guidanceKeys = snapshotRoot.optJSONArray("guidanceKeys")?.let { array ->
                    val keys = mutableSetOf<String>()
                    for (i in 0 until array.length()) {
                        array.optString(i).takeIf { it.isNotBlank() }?.let(keys::add)
                    }
                    keys.toSet()
                } ?: emptySet(),
            )
        }.getOrNull()
    }

    fun clearNavigationSession() {
        prefs.edit()
            .remove("car_navigation_route_v3")
            .remove("car_navigation_snapshot_v3")
            .remove("car_active_stage_id")
            .remove("car_selected_trip_id")
            .apply()
    }

    fun setRecording(active: Boolean) {
        prefs.edit().putBoolean("car_recording", active).apply()
        bridge.setRecording(active)
    }

    fun isRecording(): Boolean = bridge.isRecording()

    fun appendRecordedRide(json: String) {
        bridge.appendRecordedRide(json)
    }

    private fun JSONArray?.toTrips(): List<CarTrip> {
        if (this == null) return emptyList()
        return buildList {
            for (i in 0 until length()) {
                val row = optJSONObject(i) ?: continue
                add(
                    CarTrip(
                        id = row.optString("id"),
                        name = row.optString("name", "Tur"),
                        start = row.optString("start"),
                        end = row.optString("end"),
                        status = row.optString("status", "planned"),
                        stages = row.optJSONArray("stages").toStages()
                    )
                )
            }
        }
    }

    private fun JSONArray?.toStages(): List<CarStage> {
        if (this == null) return emptyList()
        return buildList {
            for (i in 0 until length()) {
                val row = optJSONObject(i) ?: continue
                add(
                    CarStage(
                        id = row.optString("id"),
                        day = row.optInt("day"),
                        order = row.optInt("order"),
                        start = row.optString("start"),
                        end = row.optString("end"),
                        transport = row.optString("transport"),
                        name = row.optString("name"),
                        status = row.optString("status", "planned"),
                        routeId = row.optString("routeId", row.optString("officialRouteId", row.optString("id"))),
                        waypoints = row.optJSONArray("waypoints").toWaypoints(),
                        distanceMeters = row.optInt("distanceMeters"),
                        durationSeconds = row.optInt("durationSeconds"),
                        geometry = row.optJSONArray("geometry").toPoints(),
                        maneuvers = row.optJSONArray("maneuvers").toManeuvers(),
                        speedLimitSections = row.optJSONArray("speedLimitSections").toSpeedLimitSections(),
                        routeProfile = row.optString("routeProfile", "fastest").ifBlank { "fastest" },
                        routePreferences = row.optJSONObject("routePreferences").toRoutePreferences(),
                    )
                )
            }
        }.sortedWith(compareBy<CarStage> { it.day }.thenBy { it.order })
    }

    private fun JSONArray?.toWaypoints(): List<CarWaypoint> {
        if (this == null) return emptyList()
        return buildList {
            for (i in 0 until length()) {
                val row = optJSONObject(i) ?: continue
                val loc = row.optJSONArray("location")
                add(
                    CarWaypoint(
                        id = row.optString("id", "waypoint-$i"),
                        name = row.optString("name", "Punkt ${i + 1}"),
                        kind = row.optString("kind", "via"),
                        category = row.optString("category"),
                        note = row.optString("note"),
                        distanceFromStartMeters = row.optInt("distanceFromStartMeters"),
                        location = if (loc != null && loc.length() >= 2) CarPoint(loc.optDouble(0), loc.optDouble(1)) else null,
                    )
                )
            }
        }
    }

    private fun org.json.JSONObject?.toRoutePreferences(): CarRoutePreferences {
        val row = this ?: return CarRoutePreferences()
        return CarRoutePreferences(
            avoidMotorways = row.optBoolean("avoidMotorways"),
            avoidTolls = row.optBoolean("avoidTolls"),
            avoidFerries = row.optBoolean("avoidFerries"),
            avoidUnpaved = row.optBoolean("avoidUnpaved"),
            avoidCities = row.optBoolean("avoidCities"),
            preferScenic = row.optBoolean("preferScenic"),
            preferCoastal = row.optBoolean("preferCoastal"),
            preferMountains = row.optBoolean("preferMountains"),
        )
    }

    private fun JSONArray?.toPoints(): List<CarPoint> {
        if (this == null) return emptyList()
        return buildList {
            for (i in 0 until length()) {
                val point = optJSONArray(i) ?: continue
                if (point.length() >= 2) add(CarPoint(point.optDouble(0), point.optDouble(1)))
            }
        }
    }


    private fun JSONArray?.toSpeedLimitSections(): List<CarSpeedLimitSection> {
        if (this == null) return emptyList()
        return buildList {
            for (i in 0 until length()) {
                val row = optJSONObject(i) ?: continue
                val start = row.optInt("startDistanceMeters", -1)
                val end = row.optInt("endDistanceMeters", -1)
                val speed = row.optInt("speedLimitKph", -1)
                if (start < 0 || end <= start || speed <= 0 || speed > 200) continue
                add(
                    CarSpeedLimitSection(
                        startDistanceMeters = start,
                        endDistanceMeters = end,
                        speedLimitKph = speed,
                        startPathIndex = row.optInt("startPathIndex", -1).takeIf { it >= 0 },
                        endPathIndex = row.optInt("endPathIndex", -1).takeIf { it >= 0 },
                        source = row.optString("source", "provider"),
                        confidence = row.optDouble("confidence", 1.0).coerceIn(0.0, 1.0),
                    ),
                )
            }
        }.sortedBy { it.startDistanceMeters }
    }

    private fun JSONArray?.toManeuvers(): List<CarManeuver> {
        if (this == null) return emptyList()
        return buildList {
            for (i in 0 until length()) {
                val row = optJSONObject(i) ?: continue
                val loc = row.optJSONArray("location")
                add(
                    CarManeuver(
                        id = row.optString("id"),
                        sequence = row.optInt("sequence"),
                        type = row.optString("type", "turn"),
                        modifier = row.optString("modifier"),
                        instruction = row.optString("instruction", "Fortsett"),
                        roadName = row.optString("roadName"),
                        roadRef = row.optString("roadRef"),
                        distanceMeters = row.optInt("distanceMeters"),
                        durationSeconds = row.optInt("durationSeconds"),
                        distanceFromStartMeters = row.optInt("distanceFromStartMeters"),
                        exit = row.optInt("exit").takeIf { row.has("exit") && !row.isNull("exit") },
                        source = row.optString("source", "none"),
                        confidence = row.optDouble("confidence", 0.0),
                        location = if (loc != null && loc.length() >= 2) CarPoint(loc.optDouble(0), loc.optDouble(1)) else null,
                    )
                )
            }
        }.sortedBy { it.sequence }
    }


    private fun CarStage.toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("day", day)
        .put("order", order)
        .put("start", start)
        .put("end", end)
        .put("transport", transport)
        .put("name", name)
        .put("status", status)
        .put("routeId", routeId)
        .put("distanceMeters", distanceMeters)
        .put("durationSeconds", durationSeconds)
        .put("routeProfile", routeProfile)
        .put("routePreferences", JSONObject()
            .put("avoidMotorways", routePreferences.avoidMotorways)
            .put("avoidTolls", routePreferences.avoidTolls)
            .put("avoidFerries", routePreferences.avoidFerries)
            .put("avoidUnpaved", routePreferences.avoidUnpaved)
            .put("avoidCities", routePreferences.avoidCities)
            .put("preferScenic", routePreferences.preferScenic)
            .put("preferCoastal", routePreferences.preferCoastal)
            .put("preferMountains", routePreferences.preferMountains))
        .put("geometry", JSONArray().apply { geometry.forEach { put(JSONArray().put(it.lon).put(it.lat)) } })
        .put("speedLimitSections", JSONArray().apply { speedLimitSections.forEach { section -> put(JSONObject()
            .put("startDistanceMeters", section.startDistanceMeters)
            .put("endDistanceMeters", section.endDistanceMeters)
            .put("speedLimitKph", section.speedLimitKph)
            .apply { section.startPathIndex?.let { put("startPathIndex", it) } }
            .apply { section.endPathIndex?.let { put("endPathIndex", it) } }
            .put("source", section.source)
            .put("confidence", section.confidence)) } })
        .put("waypoints", JSONArray().apply { waypoints.forEach { waypoint -> put(JSONObject()
            .put("id", waypoint.id).put("name", waypoint.name).put("kind", waypoint.kind)
            .put("category", waypoint.category).put("note", waypoint.note)
            .put("distanceFromStartMeters", waypoint.distanceFromStartMeters)
            .put("location", waypoint.location?.let { JSONArray().put(it.lon).put(it.lat) })) } })
        .put("maneuvers", JSONArray().apply { maneuvers.forEach { maneuver -> put(JSONObject()
            .put("id", maneuver.id).put("sequence", maneuver.sequence).put("type", maneuver.type)
            .put("modifier", maneuver.modifier).put("instruction", maneuver.instruction)
            .put("roadName", maneuver.roadName).put("roadRef", maneuver.roadRef)
            .put("distanceMeters", maneuver.distanceMeters).put("durationSeconds", maneuver.durationSeconds)
            .put("distanceFromStartMeters", maneuver.distanceFromStartMeters).put("exit", maneuver.exit)
            .put("source", maneuver.source).put("confidence", maneuver.confidence)
            .put("location", maneuver.location?.let { JSONArray().put(it.lon).put(it.lat) })) } })

    private fun JSONArray?.toPois(): List<CarPoi> {
        if (this == null) return emptyList()
        return buildList {
            for (i in 0 until length()) {
                val row = optJSONObject(i) ?: continue
                add(CarPoi(row.optString("id"), row.optString("name"), row.optString("category"), row.optInt("distanceMeters")))
            }
        }
    }
}
