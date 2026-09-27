package no.govia.mobile.car

import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import no.govia.mobile.R
import java.util.Locale

class GoViaCarTripDetailScreen(carContext: CarContext, private val trip: CarTrip) : Screen(carContext), DefaultLifecycleObserver {
    private val repo = GoViaCarRepository(carContext)
    private val appManager = carContext.getCarService(AppManager::class.java)
    private val geometry = trip.stages.flatMap { it.geometry }
    private val mapSurface = GoViaCarMapSurface(carContext, geometry)

    init {
        lifecycle.addObserver(this)
        appManager.setSurfaceCallback(mapSurface)
        mapSurface.setDarkMode(resolveDarkMode())
    }

    override fun onDestroy(owner: LifecycleOwner) {
        appManager.setSurfaceCallback(null)
        mapSurface.close()
    }

    override fun onGetTemplate(): Template {
        mapSurface.setDarkMode(resolveDarkMode())
        val km = trip.totalDistanceMeters / 1000.0
        val minutes = trip.totalDurationSeconds / 60
        val poiCount = repo.readState().pois.size
        val stopCount = trip.stages.size + 1

        val pane = Pane.Builder()
            .addRow(Row.Builder().setTitle("${trip.start} → ${trip.end}").build())
            .addRow(Row.Builder().setTitle(String.format(Locale("nb", "NO"), "%.0f km · %d t %02d min", km, minutes / 60, minutes % 60)).build())
            .addRow(Row.Builder().setTitle("$poiCount POI · $stopCount stopp").build())
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

        val content = PaneTemplate.Builder(pane)
            .setTitle(trip.name)
            .setHeaderAction(Action.BACK)
            .build()

        val mapActions = ActionStrip.Builder()
            .addAction(Action.PAN)
            .addAction(iconAction(R.drawable.ic_car_recenter) { mapSurface.frameOverview() })
            .addAction(iconAction(R.drawable.ic_car_zoom_in) { mapSurface.zoomBy(1.0) })
            .addAction(iconAction(R.drawable.ic_car_zoom_out) { mapSurface.zoomBy(-1.0) })
            .build()

        if (carContext.carAppApiLevel < 7) return content

        return MapWithContentTemplate.Builder()
            .setContentTemplate(content)
            .setMapController(MapController.Builder().setMapActionStrip(mapActions).build())
            .build()
    }

    private fun iconAction(drawable: Int, action: () -> Unit): Action =
        Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build())
            .setOnClickListener(action)
            .build()

    private fun resolveDarkMode(): Boolean = when (repo.readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> carContext.isDarkMode
    }
}
