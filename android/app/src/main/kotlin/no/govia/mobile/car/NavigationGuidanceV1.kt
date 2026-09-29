package no.govia.mobile.car

import java.util.Locale
import kotlin.math.roundToInt

enum class CarGuidancePhase { PREPARE, APPROACH, NOW }

data class CarGuidanceThresholds(val prepareMeters: Double, val approachMeters: Double, val nowMeters: Double)

data class CarGuidanceCue(
    val maneuverId: String,
    val phase: CarGuidancePhase,
    val primaryText: String,
    val spokenText: String,
    val distanceMeters: Double,
) {
    val dedupeKey: String get() = "$maneuverId:${phase.name.lowercase(Locale.ROOT)}"
}

/** Deterministic Guidance v1 policy. NavigationCoreV2 remains the progression authority. */
object NavigationGuidanceV1 {
    fun thresholds(speedMetersPerSecond: Double): CarGuidanceThresholds {
        val speed = speedMetersPerSecond.coerceIn(0.0, 45.0)
        return CarGuidanceThresholds(
            prepareMeters = (speed * 28.0).coerceIn(300.0, 1100.0),
            approachMeters = (speed * 10.0).coerceIn(120.0, 380.0),
            nowMeters = (speed * 2.5).coerceIn(45.0, 80.0),
        )
    }

    fun phaseFor(distanceMeters: Double, speedMetersPerSecond: Double): CarGuidancePhase? {
        val t = thresholds(speedMetersPerSecond)
        return when {
            distanceMeters <= t.nowMeters -> CarGuidancePhase.NOW
            distanceMeters <= t.approachMeters -> CarGuidancePhase.APPROACH
            distanceMeters <= t.prepareMeters -> CarGuidancePhase.PREPARE
            else -> null
        }
    }

    fun cueFor(maneuver: CarManeuver, distanceMeters: Double, speedMetersPerSecond: Double): CarGuidanceCue? {
        if (!isVoiceActionable(maneuver)) return null
        val phase = phaseFor(distanceMeters, speedMetersPerSecond) ?: return null
        val primary = primaryInstruction(maneuver, concise = phase == CarGuidancePhase.NOW)
        val spoken = if (phase == CarGuidancePhase.NOW) primary else "Om ${spokenDistance(distanceMeters)}, $primary"
        return CarGuidanceCue(maneuver.id, phase, primary, spoken, distanceMeters)
    }

    fun primaryInstruction(maneuver: CarManeuver, concise: Boolean = false): String {
        val type = semanticType(maneuver)
        val modifier = normalizeToken(maneuver.modifier)
        val destination = roadLabel(maneuver)

        if (type == "roundabout") {
            maneuver.exit?.takeIf { it > 0 }?.let { exit ->
                val base = if (concise) "Ta ${ordinal(exit)} avkjøring" else "I rundkjøringen, ta ${ordinal(exit)} avkjøring"
                return if (destination.isBlank()) base else "$base mot $destination"
            }
            val base = "Kjør inn i rundkjøringen"
            return if (destination.isBlank()) base else "$base mot $destination"
        }

        if (type == "exit") {
            val base = maneuver.exit?.takeIf { it > 0 }?.let { "Ta avkjøring $it" } ?: "Ta neste avkjøring"
            return if (destination.isBlank()) base else "$base mot $destination"
        }

        if (type == "on ramp") {
            val base = "Ta påkjøringsrampen"
            return if (destination.isBlank()) base else "$base mot $destination"
        }

        if (type == "merge") {
            val side = when {
                modifier.contains("left") -> " til venstre"
                modifier.contains("right") -> " til høyre"
                else -> ""
            }
            val base = "Flett inn$side"
            return if (destination.isBlank()) base else "$base mot $destination"
        }

        if (type == "fork") {
            val side = when {
                modifier.contains("left") -> "venstre"
                modifier.contains("right") -> "høyre"
                else -> ""
            }
            val base = if (side.isBlank()) "Hold kursen" else "Hold til $side"
            return if (destination.isBlank()) base else "$base mot $destination"
        }

        if (type == "continue" || type == "new name" || type == "notification") {
            return if (destination.isBlank()) "Fortsett" else "Fortsett på $destination"
        }

        val direction = when (modifier) {
            "left", "slight left", "sharp left" -> "Ta til venstre"
            "right", "slight right", "sharp right" -> "Ta til høyre"
            "uturn", "u turn" -> "Snu"
            else -> ""
        }
        if (direction.isNotBlank()) return if (destination.isBlank()) direction else "$direction mot $destination"

        val fallback = clean(maneuver.instruction)
        return when {
            fallback.isNotBlank() -> fallback
            destination.isNotBlank() -> "Fortsett mot $destination"
            else -> "Fortsett"
        }
    }

    fun semanticType(maneuver: CarManeuver): String {
        val type = normalizeToken(maneuver.type)
        if (type.contains("roundabout") || type == "rotary" || type.contains("traffic circle")) return "roundabout"
        if (type.contains("off ramp") || type == "exit" || type.contains("motorway exit")) return "exit"
        if (type.contains("on ramp") || type == "onramp") return "on ramp"
        if (type == "new name" || type == "newname") return "new name"
        if (type == "end of road" || type == "endofroad") return "end of road"
        return type
    }

    fun isVoiceActionable(maneuver: CarManeuver): Boolean {
        val type = semanticType(maneuver)
        val source = normalizeToken(maneuver.source)
        if (source.contains("geometry")) {
            return type in setOf("roundabout", "exit", "on ramp", "merge", "fork", "end of road")
        }
        if (type == "notification" || type == "new name") return false
        return type.isNotBlank() && type != "depart" && type != "arrive"
    }

    private fun normalizeToken(value: String): String = clean(value)
        .lowercase(Locale.ROOT)
        .replace('_', ' ')
        .replace('-', ' ')
        .replace(Regex("\\s+"), " ")

    fun nextInstruction(maneuver: CarManeuver): String = "Deretter ${primaryInstruction(maneuver, concise = true).replaceFirstChar { it.lowercase(Locale.forLanguageTag("nb-NO")) }}"

    fun roadLabel(maneuver: CarManeuver): String {
        val ref = clean(maneuver.roadRef)
        val name = clean(maneuver.roadName)
        return when {
            ref.isBlank() -> name
            name.isBlank() || name.contains(ref, ignoreCase = true) -> ref
            else -> "$ref $name"
        }
    }

    fun spokenDistance(meters: Double): String {
        if (meters >= 1000.0) {
            val km = meters / 1000.0
            return String.format(Locale.forLanguageTag("nb-NO"), if (km >= 5) "%.0f kilometer" else "%.1f kilometer", km)
        }
        val rounded = when {
            meters >= 300 -> (meters / 100).roundToInt() * 100
            meters >= 100 -> (meters / 50).roundToInt() * 50
            else -> (meters / 10).roundToInt() * 10
        }
        return "$rounded meter"
    }

    private fun ordinal(value: Int): String = when (value) {
        1 -> "første"
        2 -> "andre"
        3 -> "tredje"
        4 -> "fjerde"
        5 -> "femte"
        6 -> "sjette"
        7 -> "sjuende"
        8 -> "åttende"
        9 -> "niende"
        10 -> "tiende"
        else -> "$value."
    }

    private fun clean(value: String): String = value.trim().replace(Regex("\\s+"), " ")
}
