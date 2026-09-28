package no.govia.mobile.car

import android.content.Context
import no.govia.mobile.CarBridgeStore
import org.json.JSONArray
import org.json.JSONObject

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

    fun setRecording(active: Boolean) {
        prefs.edit().putBoolean("car_recording", active).apply()
    }

    fun isRecording(): Boolean = prefs.getBoolean("car_recording", false)

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
                        waypoints = row.optJSONArray("waypoints").toWaypoints(),
                        distanceMeters = row.optInt("distanceMeters"),
                        durationSeconds = row.optInt("durationSeconds"),
                        geometry = row.optJSONArray("geometry").toPoints(),
                        maneuvers = row.optJSONArray("maneuvers").toManeuvers(),
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
                        instruction = row.optString("instruction", "Fortsett"),
                        roadName = row.optString("roadName"),
                        distanceMeters = row.optInt("distanceMeters"),
                        distanceFromStartMeters = row.optInt("distanceFromStartMeters"),
                        location = if (loc != null && loc.length() >= 2) CarPoint(loc.optDouble(0), loc.optDouble(1)) else null
                    )
                )
            }
        }.sortedBy { it.sequence }
    }

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
