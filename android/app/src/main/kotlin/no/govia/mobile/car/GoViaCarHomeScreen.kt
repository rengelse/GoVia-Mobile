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

class GoViaCarHomeScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val repo = GoViaCarRepository(carContext)
        val state = repo.readState()
        val list = ItemList.Builder()

        state.activeTripId?.let { activeId ->
            state.trips.firstOrNull { it.id == activeId }?.let { active ->
                list.addItem(
                    Row.Builder()
                        .setTitle("Fortsett tur")
                        .addText(compactRoute(active))
                        .setBrowsable(true)
                        .setOnClickListener { screenManager.push(GoViaCarNavigationScreen(carContext, active)) }
                        .build()
                )
            }
        }

        list.addItem(
            Row.Builder()
                .setTitle("Turer")
                .setImage(carIcon(R.drawable.ic_car_trips))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(GoViaCarTripsScreen(carContext)) }
                .build()
        )
        list.addItem(
            Row.Builder()
                .setTitle(if (repo.isRecording()) "Opptak pågår" else "Ta opp")
                .setImage(carIcon(R.drawable.ic_car_record))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(GoViaCarRecordScreen(carContext)) }
                .build()
        )

        return ListTemplate.Builder()
            .setTitle("GoVia")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(list.build())
            .build()
    }

    private fun compactRoute(trip: CarTrip): String {
        val start = trip.start.removePrefix("Her · ").removeSuffix(", Norway").trim()
        val end = trip.end.removeSuffix(", Norway").trim()
        return "$start → $end".take(56)
    }

    private fun carIcon(drawable: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build()
}
