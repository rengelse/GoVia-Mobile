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

/**
 * Native GoVia landing screen.
 *
 * Android Auto owns the chrome, typography and row geometry. GoVia owns the information
 * architecture, labels, icons and navigation flow. The app icon shown in the header is the
 * real application icon supplied to the host by Action.APP_ICON.
 */
class GoViaCarHomeScreen(
    carContext: CarContext,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        runtime.mapSurface.updateRoute(emptyList())
        runtime.mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.BROWSE)

        val items = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle("Turer")
                    .addText("Velg en planlagt, aktiv eller fullført GoVia-tur")
                    .setImage(carIcon(R.drawable.ic_car_trips))
                    .setBrowsable(true)
                    .setOnClickListener {
                        screenManager.push(GoViaCarTripsScreen(carContext, runtime))
                    }
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle("Ta opp tur")
                    .addText("Registrer turen du faktisk kjører")
                    .setImage(carIcon(R.drawable.ic_car_record))
                    .setBrowsable(true)
                    .setOnClickListener {
                        screenManager.push(GoViaCarRecordScreen(carContext, runtime))
                    }
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle("Søk destinasjon")
                    .addText("Finn adresse eller sted og start navigasjon")
                    .setImage(carIcon(R.drawable.ic_car_search))
                    .setBrowsable(true)
                    .setOnClickListener {
                        screenManager.push(GoViaCarSearchScreen(carContext, runtime))
                    }
                    .build(),
            )
            .build()

        return ListTemplate.Builder()
            .setTitle("GoVia")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(items)
            .build()
    }

    private fun carIcon(drawable: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build()
}
