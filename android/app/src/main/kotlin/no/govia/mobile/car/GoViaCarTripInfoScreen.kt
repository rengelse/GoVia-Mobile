package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import java.util.Locale

/** Native detail list opened from route preview. */
class GoViaCarTripInfoScreen(
    carContext: CarContext,
    private val trip: CarTrip,
) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val km = trip.totalDistanceMeters / 1000.0
        val minutes = (trip.totalDurationSeconds / 60).coerceAtLeast(1)
        val duration = if (minutes >= 60) "${minutes / 60} t ${minutes % 60} min" else "$minutes min"
        val stops = (trip.stages.size + 1).coerceAtLeast(2)

        val list = ItemList.Builder()
            .addItem(Row.Builder().setTitle("Fra").addText(clean(trip.start)).build())
            .addItem(Row.Builder().setTitle("Til").addText(clean(trip.end)).build())
            .addItem(
                Row.Builder()
                    .setTitle("Distanse")
                    .addText(String.format(Locale("nb", "NO"), "%.0f km", km))
                    .build(),
            )
            .addItem(Row.Builder().setTitle("Estimert kjøretid").addText(duration).build())
            .addItem(Row.Builder().setTitle("Stopp").addText("$stops").build())
            .build()

        return ListTemplate.Builder()
            .setTitle(clean(trip.name))
            .setHeaderAction(Action.BACK)
            .setSingleList(list)
            .build()
    }

    private fun clean(value: String): String = value
        .removePrefix("Her · ")
        .removeSuffix(", Norway")
        .replace(Regex("\\s+"), " ")
        .trim()
        .ifBlank { "Valgt sted" }
        .take(60)
}
