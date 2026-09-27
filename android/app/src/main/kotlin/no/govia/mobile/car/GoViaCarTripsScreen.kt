package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

class GoViaCarTripsScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val trips = GoViaCarRepository(carContext).readState().trips
            .filter { it.status == "planned" || it.status == "active" }
        val list = ItemList.Builder().setNoItemsMessage("Ingen planlagte eller aktive turer. Åpne GoVia på telefonen for å synkronisere.")
        trips.forEach { trip ->
            val km = trip.totalDistanceMeters / 1000.0
            list.addItem(
                Row.Builder()
                    .setTitle(trip.name)
                    .addText("${trip.start} → ${trip.end}")
                    .addText(String.format("%.0f km · %d etapper", km, trip.stages.size))
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
}
