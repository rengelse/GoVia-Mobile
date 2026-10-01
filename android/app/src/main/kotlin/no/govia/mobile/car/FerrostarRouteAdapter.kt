package no.govia.mobile.car

import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt
import uniffi.ferrostar.BoundingBox
import uniffi.ferrostar.DrivingSide
import uniffi.ferrostar.GeographicCoordinate
import uniffi.ferrostar.ManeuverModifier
import uniffi.ferrostar.ManeuverType
import uniffi.ferrostar.Route
import uniffi.ferrostar.RouteStep
import uniffi.ferrostar.SpokenInstruction
import uniffi.ferrostar.VisualInstruction
import uniffi.ferrostar.VisualInstructionContent
import uniffi.ferrostar.Waypoint
import uniffi.ferrostar.WaypointKind

/**
 * Canonical GoVia -> Ferrostar route contract.
 *
 * Navigation decisions always come from provider maneuver metadata. A maneuver may carry an
 * explicit provider shapeIndex; for older payloads we accept only an exact route-coordinate match.
 * We never nearest-project a maneuver onto route geometry and never synthesize directional turns
 * from route curvature.
 */
object FerrostarRouteAdapter {
    data class AnchoredManeuver(val maneuver: CarManeuver, val shapeIndex: Int)

    data class AdaptedRoute(
        val route: Route,
        val anchoredManeuvers: List<AnchoredManeuver>,
        val stepStartShapeIndexes: List<Int>,
    )

    fun convert(stage: CarStage): AdaptedRoute {
        require(stage.geometry.size >= 2) { "Route requires at least two geometry points" }
        require(stage.distanceMeters > 0) { "Route distance must be positive" }
        require(stage.maneuvers.isNotEmpty()) { "Provider guidance is required for navigation" }

        val geometry = stage.geometry.map { GeographicCoordinate(lat = it.lat, lng = it.lon) }
        val anchored = anchorProviderManeuvers(stage)
        val steps = anchored.mapIndexed { index, anchoredManeuver ->
            val maneuver = anchoredManeuver.maneuver
            val next = anchored.getOrNull(index + 1)
            val startIndex = anchoredManeuver.shapeIndex
            val endIndex = (next?.shapeIndex ?: geometry.lastIndex).coerceIn(startIndex, geometry.lastIndex)
            val stepGeometry = geometry.subList(startIndex, endIndex + 1).let {
                if (it.size >= 2) it else listOf(geometry[startIndex], geometry[startIndex])
            }
            val nextOffset = next?.maneuver?.distanceFromStartMeters?.toDouble() ?: stage.distanceMeters.toDouble()
            val stepDistance = max(0.0, nextOffset - maneuver.distanceFromStartMeters.toDouble())
            val stepDuration = if (stage.distanceMeters > 0) {
                stage.durationSeconds * (stepDistance / stage.distanceMeters.toDouble())
            } else 0.0

            RouteStep(
                geometry = stepGeometry,
                distance = stepDistance,
                duration = stepDuration,
                roadName = maneuver.roadName.ifBlank { null },
                exits = maneuver.exit?.let { listOf(it.toString()) } ?: emptyList(),
                instruction = maneuver.instruction,
                visualInstructions = listOf(
                    VisualInstruction(
                        primaryContent = VisualInstructionContent(
                            text = visualText(maneuver),
                            maneuverType = maneuverType(maneuver.type),
                            maneuverModifier = maneuverModifier(maneuver.modifier),
                            roundaboutExitDegrees = null,
                            laneInfo = null,
                            exitNumbers = maneuver.exit?.let { listOf(it.toString()) } ?: emptyList(),
                        ),
                        secondaryContent = null,
                        subContent = null,
                        triggerDistanceBeforeManeuver = stepDistance,
                    ),
                ),
                spokenInstructions = spokenInstructions(maneuver, stepDistance),
                annotations = annotationsForStep(
                    stage.speedLimitSections,
                    startIndex,
                    endIndex,
                    geometry.lastIndex,
                    stepGeometry.size,
                ),
                incidents = emptyList(),
                drivingSide = DrivingSide.RIGHT,
                roundaboutExitNumber = if (maneuver.type.lowercase() in setOf("roundabout", "rotary")) {
                    maneuver.exit?.coerceIn(1, 255)?.toUByte()
                } else {
                    null
                },
            )
        }

        return AdaptedRoute(
            route = Route(
                geometry = geometry,
                bbox = boundingBox(geometry),
                distance = stage.distanceMeters.toDouble(),
                waypoints = listOf(
                    Waypoint(coordinate = geometry.first(), kind = WaypointKind.BREAK),
                    Waypoint(coordinate = geometry.last(), kind = WaypointKind.BREAK),
                ),
                steps = steps,
            ),
            anchoredManeuvers = anchored,
            stepStartShapeIndexes = anchored.map { it.shapeIndex },
        )
    }

    private fun anchorProviderManeuvers(stage: CarStage): List<AnchoredManeuver> {
        var previous = 0
        return stage.maneuvers.sortedBy { it.sequence }.map { maneuver ->
            val explicit = maneuver.shapeIndex?.takeIf { it in stage.geometry.indices && it >= previous }
            val exact = if (explicit == null) exactShapeIndex(stage.geometry, maneuver.location, previous) else null
            val resolved = explicit ?: exact
                ?: throw IllegalArgumentException(
                    "Maneuver ${maneuver.id} lacks provider shapeIndex and does not exactly match route geometry",
                )
            previous = resolved
            AnchoredManeuver(maneuver, resolved)
        }
    }

    private fun exactShapeIndex(geometry: List<CarPoint>, location: CarPoint?, start: Int): Int? {
        val point = location ?: return null
        // Provider coordinates are serialized decimal values. Tiny JSON floating representation
        // differences are accepted, but this is deliberately not a nearest-point projection.
        val epsilon = 1e-7
        for (index in start until geometry.size) {
            val candidate = geometry[index]
            if (abs(candidate.lat - point.lat) <= epsilon && abs(candidate.lon - point.lon) <= epsilon) {
                return index
            }
        }
        return null
    }

    private fun spokenInstructions(maneuver: CarManeuver, stepDistance: Double): List<SpokenInstruction> {
        if (!isActionable(maneuver)) return emptyList()
        val cues = mutableListOf<Pair<Double, String>>()
        if (stepDistance > 450.0) {
            val trigger = minOf(stepDistance, 800.0)
            cues += trigger to "Om ${spokenDistance(trigger)}, ${lowercaseLead(maneuver.instruction)}"
        }
        if (stepDistance > 120.0) {
            val trigger = minOf(stepDistance, 220.0)
            cues += trigger to "Om ${spokenDistance(trigger)}, ${lowercaseLead(maneuver.instruction)}"
        }
        cues += minOf(stepDistance, 45.0).coerceAtLeast(0.0) to maneuver.instruction

        return cues
            .distinctBy { it.first.roundToIntSafe() }
            .sortedByDescending { it.first }
            .mapIndexed { index, (distance, text) ->
                SpokenInstruction(
                    text = text,
                    ssml = null,
                    triggerDistanceBeforeManeuver = distance,
                    utteranceId = UUID.nameUUIDFromBytes("govia:${maneuver.id}:$index".toByteArray()),
                )
            }
    }

    fun isActionable(maneuver: CarManeuver): Boolean {
        val type = maneuver.type.lowercase()
        val modifier = maneuver.modifier.lowercase()
        if (type == "turn" && (modifier == "slight_left" || modifier == "slight_right")) return false
        if (type == "continue" && (modifier == "straight" || modifier == "slight_left" || modifier == "slight_right")) return false
        if (type == "new_name" || type == "notification") return false
        return type in setOf("turn", "off_ramp", "on_ramp", "roundabout", "fork", "merge", "end_of_road", "arrive", "depart")
    }

    private fun visualText(m: CarManeuver): String = when {
        m.roadRef.isNotBlank() && m.roadName.isNotBlank() -> "${m.instruction} · ${m.roadRef} ${m.roadName}"
        m.roadRef.isNotBlank() -> "${m.instruction} · ${m.roadRef}"
        m.roadName.isNotBlank() -> "${m.instruction} · ${m.roadName}"
        else -> m.instruction
    }

    fun maneuverType(type: String): ManeuverType = when (type.lowercase()) {
        "turn" -> ManeuverType.TURN
        "depart" -> ManeuverType.DEPART
        "arrive" -> ManeuverType.ARRIVE
        "merge" -> ManeuverType.MERGE
        "on_ramp" -> ManeuverType.ON_RAMP
        "off_ramp" -> ManeuverType.OFF_RAMP
        "fork" -> ManeuverType.FORK
        "end_of_road" -> ManeuverType.END_OF_ROAD
        "continue", "new_name" -> ManeuverType.CONTINUE
        "roundabout", "rotary" -> ManeuverType.ROUNDABOUT
        else -> ManeuverType.NOTIFICATION
    }

    fun maneuverModifier(modifier: String): ManeuverModifier = when (modifier.lowercase()) {
        "uturn", "u_turn" -> ManeuverModifier.U_TURN
        "sharp_right" -> ManeuverModifier.SHARP_RIGHT
        "right" -> ManeuverModifier.RIGHT
        "slight_right" -> ManeuverModifier.SLIGHT_RIGHT
        "slight_left" -> ManeuverModifier.SLIGHT_LEFT
        "left" -> ManeuverModifier.LEFT
        "sharp_left" -> ManeuverModifier.SHARP_LEFT
        else -> ManeuverModifier.STRAIGHT
    }

    private fun annotationsForStep(
        sections: List<CarSpeedLimitSection>,
        startIndex: Int,
        endIndex: Int,
        routeLastIndex: Int,
        stepGeometrySize: Int,
    ): List<String>? {
        if (endIndex < startIndex || stepGeometrySize <= 0) return null
        // Ferrostar indexes annotations with currentStepGeometryIndex, i.e. by coordinate index
        // within the active RouteStep. Keep annotations exactly aligned with stepGeometry, not
        // one-short as a segment-only array. Zero-length provider steps duplicate their sole
        // coordinate in stepGeometry, so duplicate the annotation as well.
        val coordinateIndexes = (startIndex..endIndex).toMutableList()
        while (coordinateIndexes.size < stepGeometrySize) coordinateIndexes += endIndex
        return coordinateIndexes.take(stepGeometrySize).map { coordinateIndex ->
            val segmentIndex = if (coordinateIndex >= routeLastIndex) {
                (routeLastIndex - 1).coerceAtLeast(0)
            } else {
                coordinateIndex
            }
            val limit = sections.firstOrNull {
                val start = it.startPathIndex
                val end = it.endPathIndex
                start != null && end != null && segmentIndex >= start && segmentIndex < end && it.confidence >= 0.75
            }?.speedLimitKph
            if (limit == null) "{}" else "{\"speedLimitKph\":$limit}"
        }
    }

    private fun boundingBox(points: List<GeographicCoordinate>): BoundingBox = BoundingBox(
        sw = GeographicCoordinate(lat = points.minOf { it.lat }, lng = points.minOf { it.lng }),
        ne = GeographicCoordinate(lat = points.maxOf { it.lat }, lng = points.maxOf { it.lng }),
    )

    private fun lowercaseLead(value: String): String = value.replaceFirstChar { if (it.isUpperCase()) it.lowercase() else it.toString() }

    private fun spokenDistance(meters: Double): String = when {
        meters >= 1000.0 -> "${(meters / 1000.0).let { if (it >= 10) it.toInt().toString() else "%.1f".format(it).replace('.', ',') }} kilometer"
        meters >= 100.0 -> "${(meters / 50.0).toInt() * 50} meter"
        else -> "${(meters / 10.0).toInt().coerceAtLeast(1) * 10} meter"
    }

    private fun Double.roundToIntSafe(): Int = if (isFinite()) roundToInt() else 0
}
