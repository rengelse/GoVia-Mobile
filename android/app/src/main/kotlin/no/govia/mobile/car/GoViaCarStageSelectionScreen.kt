package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import java.util.Locale

/** Lets the driver select exactly which stage of a multi-stage GoVia trip to navigate. */
class GoViaCarStageSelectionScreen(
    carContext: CarContext,
    private val trip: CarTrip,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val ordered = trip.stages.sortedWith(compareBy<CarStage> { it.day }.thenBy { it.order })
        val items = ItemList.Builder().setNoItemsMessage("Ingen etapper i denne turen")
        ordered.forEachIndexed { index, stage ->
            val navigable = stage.transport != "ferry" && stage.transport != "train" && stage.geometry.size >= 2
            val km = stage.distanceMeters / 1000.0
            val minutes = (stage.durationSeconds / 60).coerceAtLeast(1)
            val duration = if (minutes >= 60) "${minutes / 60} t ${minutes % 60} min" else "$minutes min"
            val title = stage.name.ifBlank { "Etappe ${index + 1}: ${clean(stage.start)} → ${clean(stage.end)}" }
            val meta = buildList {
                add(String.format(Locale("nb", "NO"), "%.0f km", km))
                add(duration)
                add(statusLabel(stage.status))
                if (stage.waypoints.isNotEmpty()) add("${stage.waypoints.size} stopp/POI")
            }.joinToString(" · ")
            items.addItem(
                Row.Builder()
                    .setTitle(title.take(60))
                    .addText(meta)
                    .setBrowsable(navigable)
                    .apply {
                        if (navigable) {
                            setOnClickListener {
                                val selectedTrip = trip.copy(
                                    start = stage.start,
                                    end = stage.end,
                                    stages = listOf(stage),
                                )
                                GoViaCarRepository(carContext).setSelectedTripId(trip.id)
                                screenManager.push(GoViaCarNavigationScreen(carContext, selectedTrip, runtime))
                            }
                        }
                    }
                    .build(),
            )
        }
        return ListTemplate.Builder()
            .setTitle("Velg etappe")
            .setHeaderAction(Action.BACK)
            .setSingleList(items.build())
            .build()
    }

    private fun statusLabel(status: String): String = when (status) {
        "active" -> "Aktiv"
        "completed" -> "Fullført"
        else -> "Ikke startet"
    }

    private fun clean(value: String): String = value.replace(Regex("\\s+"), " ").trim().ifBlank { "Valgt sted" }
}
