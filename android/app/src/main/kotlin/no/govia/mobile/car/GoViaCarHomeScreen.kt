package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

class GoViaCarHomeScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val repo = GoViaCarRepository(carContext)
        val state = repo.readState()
        val list = ItemList.Builder()

        state.activeTripId?.let { activeId ->
            state.trips.firstOrNull { it.id == activeId }?.let { active ->
                list.addItem(
                    Row.Builder()
                        .setTitle("Fortsett: ${active.name}")
                        .addText("${active.start} → ${active.end}")
                        .setBrowsable(true)
                        .setOnClickListener { screenManager.push(GoViaCarTripDetailScreen(carContext, active)) }
                        .build()
                )
            }
        }

        list.addItem(
            Row.Builder()
                .setTitle("Turer")
                .addText("Velg en planlagt eller aktiv GoVia-tur")
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(GoViaCarTripsScreen(carContext)) }
                .build()
        )
        list.addItem(
            Row.Builder()
                .setTitle("Ta opp")
                .addText(if (repo.isRecording()) "Opptak pågår" else "Registrer turen du faktisk kjører")
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
}
