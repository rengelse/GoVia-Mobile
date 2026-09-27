package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import no.govia.mobile.R
import java.util.Locale

class GoViaCarTripsScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val trips = GoViaCarRepository(carContext).readState().trips
            .sortedWith(compareBy<CarTrip> { statusRank(it.status) }.thenBy { it.name.lowercase(Locale.getDefault()) })
        val list = ItemList.Builder().setNoItemsMessage("Ingen GoVia-turer funnet. Åpne GoVia på telefonen for å synkronisere.")
        trips.forEach { trip ->
            val km = trip.totalDistanceMeters / 1000.0
            list.addItem(
                Row.Builder()
                    .setTitle(trip.name)
                    .setImage(carIcon(R.drawable.ic_car_trips))
                    .addText("${statusLabel(trip.status)} · ${trip.start} → ${trip.end}")
                    .addText(String.format(Locale("nb", "NO"), "%.0f km · %d etapper", km, trip.stages.size))
                    .setBrowsable(true)
                    .setOnClickListener { screenManager.push(GoViaCarTripDetailScreen(carContext, trip)) }
                    .build()
            )
        }
        return ListTemplate.Builder()
            .setTitle("Turer")
            .setHeaderAction(Action.BACK)
            .setSingleList(list.build())
            .build()
    }

    private fun carIcon(drawable: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build()

    private fun statusRank(status: String): Int = when (status) {
        "active" -> 0
        "planned" -> 1
        "completed" -> 2
        else -> 3
    }

    private fun statusLabel(status: String): String = when (status) {
        "active" -> "Aktiv"
        "planned" -> "Planlagt"
        "completed" -> "Fullført"
        else -> "Tur"
    }
}
