package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import java.util.Locale

class GoViaCarTripDetailScreen(carContext: CarContext, private val trip: CarTrip) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val repo = GoViaCarRepository(carContext)
        val km = trip.totalDistanceMeters / 1000.0
        val minutes = trip.totalDurationSeconds / 60
        val poiCount = repo.readState().pois.size
        val stopCount = trip.stages.size + 1
        val pane = Pane.Builder()
            .addRow(Row.Builder().setTitle("${trip.start} → ${trip.end}").build())
            .addRow(Row.Builder().setTitle(String.format(Locale("nb", "NO"), "%.0f km · ca. %d t %02d min", km, minutes / 60, minutes % 60)).build())
            .addRow(Row.Builder().setTitle("${trip.stages.size} etapper · $stopCount stopp").build())
            .addRow(Row.Builder().setTitle("POI på turen: $poiCount").build())
            .addAction(
                Action.Builder()
                    .setTitle("Start tur")
                    .setOnClickListener {
                        repo.setSelectedTripId(trip.id)
                        screenManager.push(GoViaCarNavigationScreen(carContext, trip))
                    }
                    .build()
            )
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle(trip.name)
            .setHeaderAction(Action.BACK)
            .build()
    }
}
