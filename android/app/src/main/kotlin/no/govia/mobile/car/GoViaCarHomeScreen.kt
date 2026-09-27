package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import no.govia.mobile.R

class GoViaCarHomeScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val repo = GoViaCarRepository(carContext)
        val state = repo.readState()
        val grid = ItemList.Builder()

        state.activeTripId
            ?.let { activeId -> state.trips.firstOrNull { it.id == activeId } }
            ?.let { active ->
                grid.addItem(
                    GridItem.Builder()
                        .setTitle("Fortsett tur")
                        .setText(compactRoute(active))
                        .setImage(carIcon(R.drawable.ic_car_active))
                        .setOnClickListener {
                            screenManager.push(GoViaCarNavigationScreen(carContext, active))
                        }
                        .build()
                )
            }

        grid.addItem(
            GridItem.Builder()
                .setTitle("Turer")
                .setText("Planlagte, aktive og fullførte")
                .setImage(carIcon(R.drawable.ic_car_trips))
                .setOnClickListener { screenManager.push(GoViaCarTripsScreen(carContext)) }
                .build()
        )

        grid.addItem(
            GridItem.Builder()
                .setTitle(if (repo.isRecording()) "Opptak pågår" else "Ta opp")
                .setText(if (repo.isRecording()) "Fortsett registreringen" else "Registrer turen du faktisk kjører")
                .setImage(carIcon(R.drawable.ic_car_record))
                .setOnClickListener { screenManager.push(GoViaCarRecordScreen(carContext)) }
                .build()
        )

        return GridTemplate.Builder()
            .setTitle("GoVia")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(grid.build())
            .build()
    }

    private fun compactRoute(trip: CarTrip): String {
        val start = cleanPlace(trip.start)
        val end = cleanPlace(trip.end)
        return "$start → $end".take(56)
    }

    private fun cleanPlace(value: String): String = value
        .removePrefix("Her · ")
        .removeSuffix(", Norway")
        .replace(Regex("\\s+"), " ")
        .trim()
        .ifBlank { "Valgt posisjon" }

    private fun carIcon(drawable: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build()
}
