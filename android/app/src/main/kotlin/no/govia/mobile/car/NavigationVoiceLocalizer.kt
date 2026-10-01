package no.govia.mobile.car

import kotlin.math.roundToInt

object NavigationVoiceLocalizer {
    fun arrival(language: String): String = if (language == "en") "You have arrived." else "Du er fremme."

    fun instruction(language: String, maneuver: CarManeuver, distanceMeters: Double?): String {
        val core = maneuverText(language, maneuver)
        if (distanceMeters == null || distanceMeters <= 60.0 || maneuver.type.equals("arrive", true)) return core
        val distance = distance(language, distanceMeters)
        val lower = core.replaceFirstChar { if (it.isUpperCase()) it.lowercase() else it.toString() }
        return if (language == "en") "In $distance, $lower" else "Om $distance, $lower"
    }

    private fun maneuverText(language: String, m: CarManeuver): String {
        val en = language == "en"
        val type = m.type.lowercase()
        val modifier = m.modifier.lowercase()
        val road = m.roadName.trim()
        val roadSuffix = if (road.isBlank()) "" else if (en) " onto $road" else " inn på $road"
        if (type == "arrive") return arrival(language)
        if (type == "roundabout" || type == "rotary") {
            val exit = m.exit
            if (exit != null && exit > 0) {
                return if (en) "Take the ${ordinalEn(exit)} exit at the roundabout" else "Ta ${ordinalNb(exit)} avkjøring i rundkjøringen"
            }
            return if (en) "Enter the roundabout" else "Kjør inn i rundkjøringen"
        }
        if (type == "off_ramp") return if (en) "Take the exit$roadSuffix" else "Ta avkjøringen$roadSuffix"
        if (type == "on_ramp") return if (en) "Take the ramp$roadSuffix" else "Ta påkjøringen$roadSuffix"
        if (type == "fork" && modifier.contains("left")) return if (en) "Keep left$roadSuffix" else "Hold til venstre$roadSuffix"
        if (type == "fork" && modifier.contains("right")) return if (en) "Keep right$roadSuffix" else "Hold til høyre$roadSuffix"
        if (type == "merge") return if (en) "Merge$roadSuffix" else "Flett inn$roadSuffix"
        if (modifier.contains("left")) return if (en) "Turn left$roadSuffix" else "Ta til venstre$roadSuffix"
        if (modifier.contains("right")) return if (en) "Turn right$roadSuffix" else "Ta til høyre$roadSuffix"
        return if (en) "Continue$roadSuffix" else "Fortsett$roadSuffix"
    }

    private fun distance(language: String, meters: Double): String {
        val en = language == "en"
        if (meters >= 1000.0) {
            val km = meters / 1000.0
            val value = if (km >= 10.0) km.roundToInt().toString() else String.format(if (en) java.util.Locale.US else java.util.Locale("nb", "NO"), "%.1f", km)
            return if (en) "$value kilometers" else "$value kilometer"
        }
        val rounded = if (meters >= 100.0) (meters / 50.0).roundToInt() * 50 else (meters / 10.0).roundToInt().coerceAtLeast(1) * 10
        return if (en) "$rounded meters" else "$rounded meter"
    }

    private fun ordinalNb(n: Int): String = when (n) { 1 -> "første"; 2 -> "andre"; 3 -> "tredje"; 4 -> "fjerde"; 5 -> "femte"; else -> "$n." }
    private fun ordinalEn(n: Int): String {
        val mod100 = n % 100
        if (mod100 in 11..13) return "${n}th"
        return when (n % 10) { 1 -> "${n}st"; 2 -> "${n}nd"; 3 -> "${n}rd"; else -> "${n}th" }
    }
}
