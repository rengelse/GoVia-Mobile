package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarColor
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate
import no.govia.mobile.R
import java.util.Locale

/** Native GoVia route preview: strong map identity + compact host-managed route card. */
class GoViaCarTripDetailScreen(
    carContext: CarContext,
    private val trip: CarTrip,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext) {

    private val mapSurface get() = runtime.mapSurface
    private val geometry = trip.stages.flatMap { it.geometry }

    override fun onGetTemplate(): Template {
        mapSurface.updateRoute(geometry)
        mapSurface.updateWaypoints(trip.stages.flatMap { it.waypoints })
        mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.PREVIEW)
        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.frameOverview()

        val paneTemplate = PaneTemplate.Builder(previewPane())
            .setTitle(clean(trip.name))
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
        val stageCount = trip.stages.size.coerceAtLeast(1)

        return Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle("${clean(trip.start)} → ${clean(trip.end)}")
                    .addText(String.format(Locale("nb", "NO"), "%.0f km · %s · %d etapper", km, duration, stageCount))
                    .build(),
            )
            .addAction(
                Action.Builder()
                    .setTitle(if (trip.stages.size > 1) "Velg etappe" else "Start navigasjon")
                    .setBackgroundColor(CarColor.PRIMARY)
                    .setOnClickListener {
                        if (trip.stages.size > 1) {
                            screenManager.push(GoViaCarStageSelectionScreen(carContext, trip, runtime))
                        } else {
                            val stage = trip.stages.firstOrNull()
                            if (stage != null && stage.transport != "ferry" && stage.transport != "train" && stage.geometry.size >= 2) {
                                GoViaCarRepository(carContext).setSelectedTripId(trip.id)
                                screenManager.push(GoViaCarNavigationScreen(carContext, trip, runtime))
                            }
                        }
                    }
                    .build(),
            )
            .addAction(
                Action.Builder()
                    .setTitle("Detaljer")
                    .setOnClickListener { screenManager.push(GoViaCarTripInfoScreen(carContext, trip)) }
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
        .setIcon(GoViaCarBrand.icon(carContext, drawable))
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
