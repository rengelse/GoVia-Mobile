package no.govia.mobile.car

import android.Manifest
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarColor
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.ParkedOnlyOnClickListener
import androidx.car.app.model.Template

/** Location permission flow that can be completed from the car host while parked. */
class GoViaCarLocationPermissionScreen(
    carContext: CarContext,
    private val onGranted: () -> Unit,
) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val grant = Action.Builder()
            .setTitle("Gi tilgang")
            .setBackgroundColor(CarColor.GREEN)
            .setOnClickListener(
                ParkedOnlyOnClickListener.create {
                    carContext.requestPermissions(listOf(Manifest.permission.ACCESS_FINE_LOCATION)) { approved, rejected ->
                        if (approved.contains(Manifest.permission.ACCESS_FINE_LOCATION)) {
                            onGranted()
                            finish()
                        } else if (rejected.isNotEmpty()) {
                            CarToast.makeText(
                                carContext,
                                "Posisjonstillatelse er nødvendig for navigasjon",
                                CarToast.LENGTH_LONG,
                            ).show()
                        }
                    }
                }
            )
            .build()

        return MessageTemplate.Builder("GoVia trenger posisjonstilgang for navigasjon, søk og ruteopptak.")
            .setTitle("Posisjonstilgang")
            .setHeaderAction(Action.APP_ICON)
            .addAction(grant)
            .build()
    }
}
