package no.govia.mobile.car

import android.content.Intent
import androidx.car.app.AppManager
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

/**
 * Owns the single Android Auto surface renderer for the entire car session.
 * Screens only change renderer state; they never replace/release the host SurfaceCallback.
 */
class GoViaCarSession : Session(), DefaultLifecycleObserver {
    private val mapSurface by lazy { GoViaCarMapSurface(carContext) }

    init {
        lifecycle.addObserver(this)
    }

    override fun onCreate(owner: LifecycleOwner) {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(mapSurface)
    }

    override fun onCreateScreen(intent: Intent): Screen =
        GoViaCarTripsScreen(carContext, mapSurface)

    override fun onDestroy(owner: LifecycleOwner) {
        runCatching { carContext.getCarService(AppManager::class.java).setSurfaceCallback(null) }
        mapSurface.close()
    }
}
