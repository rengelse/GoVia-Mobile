package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template

/** Confirmation gate for the destructive stop-navigation action. */
internal class GoViaCarEndTripConfirmScreen(
    carContext: CarContext,
    private val onConfirm: () -> Unit,
) : Screen(carContext) {
    override fun onGetTemplate(): Template =
        MessageTemplate.Builder("Vil du avslutte den aktive turen?")
            .setTitle("Avslutt tur")
            .setHeaderAction(Action.BACK)
            .addAction(
                Action.Builder()
                    .setTitle("Fortsett tur")
                    .setOnClickListener { screenManager.pop() }
                    .build()
            )
            .addAction(
                Action.Builder()
                    .setTitle("Avslutt tur")
                    .setOnClickListener { onConfirm() }
                    .build()
            )
            .build()
}
