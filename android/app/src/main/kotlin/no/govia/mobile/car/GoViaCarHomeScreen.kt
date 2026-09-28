package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

/**
 * Compatibility screen kept for update-package safety. The Android Auto root is GoViaCarTripsScreen.
 */
@Deprecated("Android Auto root is GoViaCarTripsScreen")
class GoViaCarHomeScreen(
    carContext: CarContext,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val list = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle("Turer")
                    .setBrowsable(true)
                    .setOnClickListener { screenManager.push(GoViaCarTripsScreen(carContext, runtime)) }
                    .build()
            )
            .build()
        return ListTemplate.Builder()
            .setTitle("GoVia")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(list)
            .build()
    }
}
