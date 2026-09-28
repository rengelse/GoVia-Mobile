package no.govia.mobile.car

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner

/**
 * Session-scoped Android Auto runtime.
 *
 * The host Surface is owned for the full car Session. Navigation/location work lives in
 * [GoViaNavigationService]. Screens only render templates and select map state.
 */
class GoViaCarRuntime(
    private val carContext: CarContext,
    lifecycle: Lifecycle,
) : DefaultLifecycleObserver, GoViaNavigationService.Listener {

    val mapSurface = GoViaCarMapSurface(carContext)

    private var navigationService: GoViaNavigationService? = null
    private var pendingTrip: CarTrip? = null
    private var navigationListener: ((GoViaNavigationService.State) -> Unit)? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            val service = (binder as GoViaNavigationService.LocalBinder).service
            navigationService = service
            service.attachCarContext(carContext, this@GoViaCarRuntime)
            pendingTrip?.let {
                pendingTrip = null
                service.startNavigation(it)
            }
            service.currentState?.let(::onNavigationStateChanged)
        }

        override fun onServiceDisconnected(name: ComponentName) {
            navigationService?.detachCarContext()
            navigationService = null
        }
    }

    init {
        lifecycle.addObserver(this)
    }

    override fun onCreate(owner: LifecycleOwner) {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(mapSurface)
    }

    override fun onStart(owner: LifecycleOwner) {
        carContext.bindService(
            Intent(carContext, GoViaNavigationService::class.java),
            serviceConnection,
            Context.BIND_AUTO_CREATE,
        )
    }

    override fun onStop(owner: LifecycleOwner) {
        runCatching { navigationService?.detachCarContext() }
        runCatching { carContext.unbindService(serviceConnection) }
        navigationService = null
    }

    override fun onDestroy(owner: LifecycleOwner) {
        navigationListener = null
        runCatching { carContext.getCarService(AppManager::class.java).setSurfaceCallback(null) }
        mapSurface.close()
    }

    fun startNavigation(trip: CarTrip, listener: (GoViaNavigationService.State) -> Unit) {
        navigationListener = listener
        mapSurface.updateRoute(trip.stages.flatMap { it.geometry })
        mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.NAVIGATION)
        val service = navigationService
        if (service == null) {
            pendingTrip = trip
        } else {
            service.startNavigation(trip)
        }
    }

    fun attachNavigationListener(listener: (GoViaNavigationService.State) -> Unit) {
        navigationListener = listener
        navigationService?.currentState?.let(listener)
    }

    fun detachNavigationListener(listener: (GoViaNavigationService.State) -> Unit) {
        if (navigationListener === listener) navigationListener = null
    }

    fun stopNavigation() {
        pendingTrip = null
        navigationService?.stopNavigation()
    }

    fun toggleVoiceMuted(): Boolean = navigationService?.toggleVoiceMuted() ?: false

    fun isVoiceMuted(): Boolean = navigationService?.currentState?.voiceMuted == true

    override fun onNavigationStateChanged(state: GoViaNavigationService.State) {
        state.location?.let(mapSurface::updatePosition)
        if (state.navigating) mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.NAVIGATION)
        navigationListener?.invoke(state)
    }
}
