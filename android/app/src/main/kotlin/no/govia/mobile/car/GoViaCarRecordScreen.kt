package no.govia.mobile.car

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.content.ContextCompat

class GoViaCarRecordScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val repo = GoViaCarRepository(carContext)
        val recording = repo.isRecording()
        val permitted = ContextCompat.checkSelfPermission(carContext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val pane = Pane.Builder()
            .addRow(Row.Builder().setTitle(if (recording) "Opptak pågår" else "Klar til opptak").build())
            .addRow(Row.Builder().setTitle(if (permitted) "GPS er tilgjengelig" else "Gi GoVia posisjonstilgang på telefonen først").build())
            .addAction(
                Action.Builder()
                    .setTitle(if (recording) "Stopp og lagre" else "Start opptak")
                    .setOnClickListener {
                        if (!permitted) return@setOnClickListener
                        val intent = Intent(carContext, CarRideRecordingService::class.java).apply {
                            action = if (recording) CarRideRecordingService.ACTION_STOP else CarRideRecordingService.ACTION_START
                        }
                        if (recording) carContext.startService(intent) else ContextCompat.startForegroundService(carContext, intent)
                        repo.setRecording(!recording)
                        invalidate()
                    }
                    .build()
            )
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle("Ta opp tur")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
