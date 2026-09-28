package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template

/** Confirmation gate before stopping and saving an active recording. */
internal class GoViaCarStopRecordingConfirmScreen(
    carContext: CarContext,
    private val onConfirm: () -> Unit,
) : Screen(carContext) {
    override fun onGetTemplate(): Template =
        MessageTemplate.Builder("Vil du stoppe opptaket og lagre turen?")
            .setTitle("Stopp opptak")
            .setHeaderAction(Action.BACK)
            .addAction(
                Action.Builder()
                    .setTitle("Fortsett opptak")
                    .setOnClickListener { screenManager.pop() }
                    .build()
            )
            .addAction(
                Action.Builder()
                    .setTitle("Stopp og lagre")
                    .setOnClickListener { onConfirm() }
                    .build()
            )
            .build()
}
