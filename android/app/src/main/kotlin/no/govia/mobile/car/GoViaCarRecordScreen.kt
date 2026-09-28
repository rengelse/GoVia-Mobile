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

/** Native recording ready screen. */
class GoViaCarRecordScreen(
    carContext: CarContext,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext) {

    private val repo = GoViaCarRepository(carContext)

    override fun onGetTemplate(): Template {
        runtime.mapSurface.updateRoute(emptyList())
        runtime.mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.BROWSE)

        val gpsReady = hasLocationPermission()
        val pane = Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle(if (repo.isRecording()) "Opptak pågår" else "Klar til opptak")
                    .addText(if (gpsReady) "GPS klar" else "Posisjonstillatelse mangler")
                    .build(),
            )
            .addRow(
                Row.Builder()
                    .setTitle("Registrer turen du faktisk kjører")
                    .addText("Opptaket lagres lokalt og kan importeres til GoVia på telefonen.")
                    .build(),
            )
            .addAction(
                Action.Builder()
                    .setTitle(if (repo.isRecording()) "Åpne opptak" else "Start opptak")
                    .setOnClickListener { startOrOpenRecording() }
                    .build(),
            )
            .build()

        return PaneTemplate.Builder(pane)
            .setTitle("Ta opp")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun startOrOpenRecording() {
        if (!hasLocationPermission()) {
            invalidate()
            return
        }
        if (!repo.isRecording()) {
            ContextCompat.startForegroundService(
                carContext,
                Intent(carContext, CarRideRecordingService::class.java).apply {
                    action = CarRideRecordingService.ACTION_START
                },
            )
            repo.setRecording(true)
        }
        screenManager.push(GoViaCarRecordingCockpitScreen(carContext, runtime))
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(carContext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
}
