package no.govia.mobile.car

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class GoViaCarRecordScreen(carContext: CarContext, private val mapSurface: GoViaCarMapSurface) : Screen(carContext), DefaultLifecycleObserver {
    private val repo = GoViaCarRepository(carContext)

    init {
        lifecycle.addObserver(this)
    }

    override fun onResume(owner: LifecycleOwner) {
        mapSurface.updateRoute(emptyList())
        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.setControlCallbacks(
            GoViaCarMapSurface.ControlCallbacks(
                onOverlayAction = { action -> handleOverlayAction(action) },
            )
        )
        refreshOverlay()
        invalidate()
    }


    override fun onGetTemplate(): Template {
        refreshOverlay()
        val requiredActionStrip = GoViaCarTemplateCompat.invisibleRequiredActionStrip()
        return NavigationTemplate.Builder()
            .setActionStrip(requiredActionStrip)
            .build()
    }

    private fun refreshOverlay() {
        mapSurface.updateRecordReadyOverlay(
            GoViaCarCockpitOverlayView.RecordReadyState(
                recording = repo.isRecording(),
                gpsReady = hasLocationPermission(),
            )
        )
    }

    private fun handleOverlayAction(action: GoViaCarCockpitOverlayView.Control) {
        when (action) {
            GoViaCarCockpitOverlayView.Control.BACK -> screenManager.pop()
            GoViaCarCockpitOverlayView.Control.START_RECORD -> startOrOpenRecording()
            else -> Unit
        }
    }

    private fun startOrOpenRecording() {
        if (!hasLocationPermission()) {
            refreshOverlay()
            invalidate()
            return
        }
        if (!repo.isRecording()) {
            val intent = Intent(carContext, CarRideRecordingService::class.java).apply {
                action = CarRideRecordingService.ACTION_START
            }
            ContextCompat.startForegroundService(carContext, intent)
            repo.setRecording(true)
        }
        screenManager.push(GoViaCarRecordingCockpitScreen(carContext, mapSurface))
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(carContext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun resolveDarkMode(): Boolean = when (repo.readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> carContext.isDarkMode
    }
}
