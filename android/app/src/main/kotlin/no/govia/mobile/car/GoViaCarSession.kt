package no.govia.mobile.car

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

class GoViaCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen = GoViaCarTripsScreen(carContext)
}
