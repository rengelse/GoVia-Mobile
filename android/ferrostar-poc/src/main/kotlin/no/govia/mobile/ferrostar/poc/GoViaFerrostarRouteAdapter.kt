package no.govia.mobile.ferrostar.poc

import java.util.UUID
import kotlin.math.max
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
 * PoC adapter only. It intentionally refuses to infer maneuver anchors from geometry.
 * If GoVia adopts Ferrostar, the server canonical route must provide provider-authoritative
 * shape/path indexes for every maneuver.
 */
object GoViaFerrostarRouteAdapter {
    fun convert(route: CanonicalRoute): Route {
        val geometry = route.geometry.map { GeographicCoordinate(lat = it.lat, lng = it.lon) }
        val ordered = route.maneuvers.sortedBy { it.shapeIndex }
        val steps = ordered.mapIndexed { index, maneuver ->
            val next = ordered.getOrNull(index + 1)
            val startIndex = maneuver.shapeIndex.coerceIn(0, geometry.lastIndex)
            val endIndex = (next?.shapeIndex ?: geometry.lastIndex).coerceIn(startIndex, geometry.lastIndex)
            val stepGeometry = geometry.subList(startIndex, endIndex + 1).let {
                if (it.size >= 2) it else listOf(geometry[startIndex], geometry[startIndex])
            }
            val stepDistance = max(0.0, (next?.routeOffsetMeters ?: route.distanceMeters) - maneuver.routeOffsetMeters)
            val stepDuration = if (route.distanceMeters > 0) {
                route.durationSeconds * (stepDistance / route.distanceMeters)
            } else 0.0

            RouteStep(
                geometry = stepGeometry,
                distance = stepDistance,
                duration = stepDuration,
                roadName = maneuver.roadName.ifBlank { null },
                exits = maneuver.exitNumber?.let { listOf(it.toString()) } ?: emptyList(),
                instruction = maneuver.instruction,
                visualInstructions = listOf(
                    VisualInstruction(
                        primaryContent = VisualInstructionContent(
                            text = visualText(maneuver),
                            maneuverType = maneuverType(maneuver.type),
                            maneuverModifier = maneuverModifier(maneuver.modifier),
                            roundaboutExitDegrees = null,
                            laneInfo = null,
                            exitNumbers = maneuver.exitNumber?.let { listOf(it.toString()) } ?: emptyList(),
                        ),
                        secondaryContent = null,
                        subContent = null,
                        triggerDistanceBeforeManeuver = stepDistance,
                    )
                ),
                spokenInstructions = spokenInstructions(maneuver, stepDistance),
                annotations = annotationsForStep(route.speedLimits, startIndex, endIndex),
                incidents = emptyList(),
                drivingSide = DrivingSide.RIGHT,
                roundaboutExitNumber = maneuver.exitNumber?.coerceIn(1, 255)?.toUByte(),
            )
        }

        return Route(
            geometry = geometry,
            bbox = boundingBox(geometry),
            distance = route.distanceMeters,
            waypoints = listOf(
                Waypoint(coordinate = geometry.first(), kind = WaypointKind.BREAK),
                Waypoint(coordinate = geometry.last(), kind = WaypointKind.BREAK),
            ),
            steps = steps,
        )
    }

    private fun spokenInstructions(maneuver: CanonicalManeuver, stepDistance: Double): List<SpokenInstruction> {
        if (!isActionable(maneuver)) return emptyList()
        return listOf(
            SpokenInstruction(
                text = maneuver.instruction,
                ssml = null,
                triggerDistanceBeforeManeuver = stepDistance,
                utteranceId = UUID.nameUUIDFromBytes("govia:${maneuver.id}".toByteArray()),
            )
        )
    }

    /** Suppress weak road bends; keep real decisions such as exits, junction turns and roundabouts. */
    internal fun isActionable(maneuver: CanonicalManeuver): Boolean {
        val type = maneuver.type.lowercase()
        val modifier = maneuver.modifier.lowercase()
        if (type == "turn" && (modifier == "slight_left" || modifier == "slight_right")) return false
        if (type == "continue" && modifier == "straight") return false
        if (type == "notification") return false
        return type in setOf("turn", "off_ramp", "on_ramp", "roundabout", "fork", "merge", "end_of_road", "arrive", "depart")
    }

    private fun visualText(m: CanonicalManeuver): String = when {
        m.roadRef.isNotBlank() && m.roadName.isNotBlank() -> "${m.instruction} · ${m.roadRef} ${m.roadName}"
        m.roadRef.isNotBlank() -> "${m.instruction} · ${m.roadRef}"
        m.roadName.isNotBlank() -> "${m.instruction} · ${m.roadName}"
        else -> m.instruction
    }

    internal fun maneuverType(type: String): ManeuverType = when (type.lowercase()) {
        "turn" -> ManeuverType.TURN
        "depart" -> ManeuverType.DEPART
        "arrive" -> ManeuverType.ARRIVE
        "merge" -> ManeuverType.MERGE
        "on_ramp" -> ManeuverType.ON_RAMP
        "off_ramp" -> ManeuverType.OFF_RAMP
        "fork" -> ManeuverType.FORK
        "end_of_road" -> ManeuverType.END_OF_ROAD
        "continue" -> ManeuverType.CONTINUE
        "roundabout" -> ManeuverType.ROUNDABOUT
        else -> ManeuverType.NOTIFICATION
    }

    internal fun maneuverModifier(modifier: String): ManeuverModifier = when (modifier.lowercase()) {
        "uturn" -> ManeuverModifier.U_TURN
        "sharp_right" -> ManeuverModifier.SHARP_RIGHT
        "right" -> ManeuverModifier.RIGHT
        "slight_right" -> ManeuverModifier.SLIGHT_RIGHT
        "slight_left" -> ManeuverModifier.SLIGHT_LEFT
        "left" -> ManeuverModifier.LEFT
        "sharp_left" -> ManeuverModifier.SHARP_LEFT
        else -> ManeuverModifier.STRAIGHT
    }

    /**
     * Ferrostar annotations are per geometry segment. We encode speed limit only when the provider
     * section covers the segment. Unknown stays unknown: no carry-forward and no guessing.
     */
    private fun annotationsForStep(
        sections: List<CanonicalSpeedLimitSection>,
        startIndex: Int,
        endIndex: Int,
    ): List<String>? {
        if (endIndex <= startIndex) return null
        return (startIndex until endIndex).map { segmentIndex ->
            val limit = sections.firstOrNull {
                segmentIndex >= it.startPathIndex && segmentIndex < it.endPathIndex
            }?.speedLimitKph
            if (limit == null) "{}" else "{\"speedLimitKph\":$limit}"
        }
    }

    private fun boundingBox(points: List<GeographicCoordinate>): BoundingBox {
        val minLat = points.minOf { it.lat }
        val maxLat = points.maxOf { it.lat }
        val minLng = points.minOf { it.lng }
        val maxLng = points.maxOf { it.lng }
        return BoundingBox(
            sw = GeographicCoordinate(lat = minLat, lng = minLng),
            ne = GeographicCoordinate(lat = maxLat, lng = maxLng),
        )
    }
}
