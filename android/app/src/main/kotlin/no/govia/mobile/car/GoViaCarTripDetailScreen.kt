package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate
import androidx.core.graphics.drawable.IconCompat
import no.govia.mobile.R
import java.util.Locale

/** Native route preview: host-managed content over the app-provided MapLibre surface. */
class GoViaCarTripDetailScreen(
    carContext: CarContext,
    private val trip: CarTrip,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext) {

    private val mapSurface get() = runtime.mapSurface
    private val geometry = trip.stages.flatMap { it.geometry }

    override fun onGetTemplate(): Template {
        mapSurface.updateRoute(geometry)
        mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.PREVIEW)
        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.frameOverview()

        val paneTemplate = PaneTemplate.Builder(previewPane())
            .setTitle("Turpreview")
            .setHeaderAction(Action.BACK)
            .build()

        if (carContext.carAppApiLevel < 7) return paneTemplate

        return MapWithContentTemplate.Builder()
            .setContentTemplate(paneTemplate)
            .setMapController(
                MapController.Builder()
                    .setMapActionStrip(mapActionStrip())
                    .build(),
            )
            .build()
    }

    private fun previewPane(): Pane {
        val km = trip.totalDistanceMeters / 1000.0
        val minutes = (trip.totalDurationSeconds / 60).coerceAtLeast(1)
        val duration = if (minutes >= 60) "${minutes / 60} t ${minutes % 60} min" else "$minutes min"
        val stops = (trip.stages.size + 1).coerceAtLeast(2)

        return Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle(clean(trip.name))
                    .addText("${clean(trip.start)} → ${clean(trip.end)}")
                    .build(),
            )
            .addRow(
                Row.Builder()
                    .setTitle(String.format(Locale("nb", "NO"), "%.0f km · %s", km, duration))
                    .addText("$stops stopp")
                    .build(),
            )
            .addAction(
                Action.Builder()
                    .setTitle("Start tur")
                    .setOnClickListener {
                        GoViaCarRepository(carContext).setSelectedTripId(trip.id)
                        screenManager.push(GoViaCarNavigationScreen(carContext, trip, runtime))
                    }
                    .build(),
            )
            .build()
    }

    private fun mapActionStrip(): ActionStrip = ActionStrip.Builder()
        .addAction(Action.PAN)
        .addAction(iconAction(R.drawable.ic_car_recenter) { mapSurface.frameOverview() })
        .addAction(iconAction(R.drawable.ic_car_zoom_in) { mapSurface.zoomBy(1.0) })
        .addAction(iconAction(R.drawable.ic_car_zoom_out) { mapSurface.zoomBy(-1.0) })
        .build()

    private fun iconAction(drawable: Int, action: () -> Unit): Action = Action.Builder()
        .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build())
        .setOnClickListener(action)
        .build()

    private fun clean(value: String): String = value
        .removePrefix("Her · ")
        .removeSuffix(", Norway")
        .replace(Regex("\\s+"), " ")
        .trim()
        .ifBlank { "Valgt sted" }
        .take(60)

    private fun resolveDarkMode(): Boolean = when (GoViaCarRepository(carContext).readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> carContext.isDarkMode
    }
}
