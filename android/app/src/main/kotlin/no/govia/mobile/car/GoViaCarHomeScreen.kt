package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import no.govia.mobile.R

/**
 * GoVia Android Auto home.
 *
 * The host still owns geometry/typography, but GridTemplate gives GoVia a much stronger,
 * purpose-built landing page than a generic settings-style ListTemplate.
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
                homeItem(
                    title = "Turer",
                    text = "Planlagt · Aktiv · Fullført",
                    icon = R.drawable.ic_car_trips,
                ) { screenManager.push(GoViaCarTripsScreen(carContext, runtime)) },
            )
            .addItem(
                homeItem(
                    title = "Søk destinasjon",
                    text = "Søk sted eller adresse",
                    icon = R.drawable.ic_car_search,
                ) { screenManager.push(GoViaCarSearchScreen(carContext, runtime)) },
            )
            .addItem(
                homeItem(
                    title = "Ta opp tur",
                    text = "Registrer turen du kjører",
                    icon = R.drawable.ic_car_record,
                ) { screenManager.push(GoViaCarRecordScreen(carContext, runtime)) },
            )
            .build()

        return GridTemplate.Builder()
            .setTitle("GoVia")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(items)
            .build()
    }

    private fun homeItem(
        title: String,
        text: String,
        icon: Int,
        onClick: () -> Unit,
    ): GridItem = GridItem.Builder()
        .setTitle(title)
        .setText(text)
        .setImage(GoViaCarBrand.icon(carContext, icon))
        .setOnClickListener(onClick)
        .build()
}
