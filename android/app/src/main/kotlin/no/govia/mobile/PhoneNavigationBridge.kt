package no.govia.mobile

import no.govia.mobile.car.CarManeuver
import no.govia.mobile.car.CarNavigationFix
import no.govia.mobile.car.CarPoint
import no.govia.mobile.car.CarRoutePreferences
import no.govia.mobile.car.CarSpeedLimitSection
import no.govia.mobile.car.CarStage
import no.govia.mobile.car.FerrostarNavigationRuntime

/** Flutter bridge for the same Ferrostar runtime used by Android Auto. */
class PhoneNavigationBridge {
    private var runtime: FerrostarNavigationRuntime? = null

    fun start(arguments: Map<*, *>): Map<String, Any?> {
        val stage = parseStage(arguments)
        runtime = FerrostarNavigationRuntime(stage)
        return stateMap(runtime!!.state)
    }

    fun updateFix(arguments: Map<*, *>): Map<String, Any?> {
        val engine = runtime ?: error("Navigation runtime is not started")
        val fix = CarNavigationFix(
            lat = arguments.number("lat").toDouble(),
            lon = arguments.number("lon").toDouble(),
            speedMetersPerSecond = arguments.numberOrNull("speedMetersPerSecond")?.toDouble() ?: 0.0,
            headingDegrees = arguments.numberOrNull("headingDegrees")?.toDouble() ?: 0.0,
            accuracyMeters = arguments.numberOrNull("accuracyMeters")?.toDouble() ?: 999.0,
            timestampMillis = arguments.numberOrNull("timestampMillis")?.toLong() ?: System.currentTimeMillis(),
        )
        return stateMap(engine.update(fix))
    }

    fun replaceRoute(arguments: Map<*, *>): Map<String, Any?> {
        val stage = parseStage(arguments)
        val previousFix = runtime?.state?.currentFix
        val engine = runtime ?: FerrostarNavigationRuntime(stage).also { runtime = it }
        return stateMap(engine.replaceRoute(stage, previousFix))
    }

    fun stop() {
        runtime = null
    }

    private fun stateMap(value: FerrostarNavigationRuntime.State): Map<String, Any?> = mapOf(
        "stageId" to value.stageId,
        "routeId" to value.routeId,
        "navigating" to value.navigating,
        "arrived" to value.arrived,
        "progressMeters" to value.progressMeters,
        "remainingMeters" to value.remainingMeters,
        "remainingSeconds" to value.remainingSeconds,
        "distanceToManeuverMeters" to value.distanceToManeuverMeters,
        "snappedPosition" to value.snappedLocation?.let { listOf(it.lon, it.lat) },
        "currentManeuver" to value.currentManeuver?.let(::maneuverMap),
        "nextManeuver" to value.nextManeuver?.let(::maneuverMap),
        "currentRoad" to value.currentRoad,
        "speedLimitKph" to value.speedLimitKph,
        "deviation" to value.deviation,
        "rerouteRequired" to value.rerouteRequired,
        "spokenInstructionId" to value.spokenInstructionId,
        "spokenInstructionText" to value.spokenInstructionText,
        "gpsQuality" to value.gpsQuality.name.lowercase(),
    )

    private fun maneuverMap(value: CarManeuver): Map<String, Any?> = mapOf(
        "id" to value.id,
        "sequence" to value.sequence,
        "type" to value.type,
        "modifier" to value.modifier,
        "instruction" to value.instruction,
        "roadName" to value.roadName,
        "roadRef" to value.roadRef,
        "distanceMeters" to value.distanceMeters,
        "durationSeconds" to value.durationSeconds,
        "distanceFromStartMeters" to value.distanceFromStartMeters,
        "shapeIndex" to value.shapeIndex,
        "exit" to value.exit,
        "source" to value.source,
        "confidence" to value.confidence,
        "location" to value.location?.let { listOf(it.lon, it.lat) },
    )

    private fun parseStage(arguments: Map<*, *>): CarStage {
        val geometry = arguments.list("geometry").mapNotNull { raw ->
            val point = raw as? List<*> ?: return@mapNotNull null
            val lon = point.getOrNull(0) as? Number ?: return@mapNotNull null
            val lat = point.getOrNull(1) as? Number ?: return@mapNotNull null
            CarPoint(lon.toDouble(), lat.toDouble())
        }
        val maneuvers = arguments.list("maneuvers").mapIndexedNotNull { index, raw ->
            val row = raw as? Map<*, *> ?: return@mapIndexedNotNull null
            val loc = (row["location"] as? List<*>)?.let { value ->
                val lon = value.getOrNull(0) as? Number
                val lat = value.getOrNull(1) as? Number
                if (lon != null && lat != null) CarPoint(lon.toDouble(), lat.toDouble()) else null
            }
            CarManeuver(
                id = row["id"]?.toString() ?: "maneuver-$index",
                sequence = (row["sequence"] as? Number)?.toInt() ?: index,
                type = row["type"]?.toString() ?: "turn",
                modifier = row["modifier"]?.toString() ?: "",
                instruction = row["instruction"]?.toString() ?: "Fortsett",
                roadName = row["roadName"]?.toString() ?: "",
                roadRef = row["roadRef"]?.toString() ?: "",
                distanceMeters = (row["distanceMeters"] as? Number)?.toInt() ?: 0,
                durationSeconds = (row["durationSeconds"] as? Number)?.toInt() ?: 0,
                distanceFromStartMeters = (row["distanceFromStartMeters"] as? Number)?.toInt() ?: 0,
                shapeIndex = ((row["shapeIndex"] ?: row["pathIndex"]) as? Number)?.toInt(),
                exit = (row["exit"] as? Number)?.toInt(),
                source = row["source"]?.toString() ?: "provider",
                confidence = (row["confidence"] as? Number)?.toDouble() ?: 1.0,
                location = loc,
            )
        }
        val speedLimits = arguments.list("speedLimitSections").mapNotNull { raw ->
            val row = raw as? Map<*, *> ?: return@mapNotNull null
            val start = (row["startDistanceMeters"] as? Number)?.toInt() ?: return@mapNotNull null
            val end = (row["endDistanceMeters"] as? Number)?.toInt() ?: return@mapNotNull null
            val speed = (row["speedLimitKph"] as? Number)?.toInt() ?: return@mapNotNull null
            CarSpeedLimitSection(
                startDistanceMeters = start,
                endDistanceMeters = end,
                speedLimitKph = speed,
                startPathIndex = (row["startPathIndex"] as? Number)?.toInt(),
                endPathIndex = (row["endPathIndex"] as? Number)?.toInt(),
                source = row["source"]?.toString() ?: "provider",
                confidence = (row["confidence"] as? Number)?.toDouble() ?: 1.0,
            )
        }
        val preferences = arguments["routePreferences"] as? Map<*, *>
        return CarStage(
            id = arguments["stageId"]?.toString() ?: error("stageId missing"),
            day = 0,
            order = 0,
            start = arguments["start"]?.toString() ?: "Start",
            end = arguments["end"]?.toString() ?: "Mål",
            transport = arguments["transport"]?.toString() ?: "driving",
            name = arguments["name"]?.toString() ?: "",
            routeId = arguments["routeId"]?.toString() ?: error("routeId missing"),
            distanceMeters = (arguments["distanceMeters"] as? Number)?.toInt() ?: 0,
            durationSeconds = (arguments["durationSeconds"] as? Number)?.toInt() ?: 0,
            geometry = geometry,
            maneuvers = maneuvers,
            speedLimitSections = speedLimits,
            routeProfile = arguments["routeProfile"]?.toString() ?: "fastest",
            routePreferences = CarRoutePreferences(
                avoidMotorways = preferences?.get("avoidMotorways") == true,
                avoidTolls = preferences?.get("avoidTolls") == true,
                avoidFerries = preferences?.get("avoidFerries") == true,
                avoidUnpaved = preferences?.get("avoidUnpaved") == true,
                avoidCities = preferences?.get("avoidCities") == true,
                preferScenic = preferences?.get("preferScenic") == true,
                preferCoastal = preferences?.get("preferCoastal") == true,
                preferMountains = preferences?.get("preferMountains") == true,
            ),
        )
    }

    private fun Map<*, *>.number(key: String): Number = this[key] as? Number ?: error("$key missing")
    private fun Map<*, *>.numberOrNull(key: String): Number? = this[key] as? Number
    private fun Map<*, *>.list(key: String): List<*> = this[key] as? List<*> ?: emptyList<Any?>()
}
