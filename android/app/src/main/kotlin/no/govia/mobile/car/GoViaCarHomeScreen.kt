package no.govia.mobile.car

import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Template
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.navigation.model.MapWithContentTemplate
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class GoViaCarHomeScreen(carContext: CarContext) : Screen(carContext), DefaultLifecycleObserver {
    private val repo = GoViaCarRepository(carContext)
    private val appManager = carContext.getCarService(AppManager::class.java)
    private val mapSurface = GoViaCarMapSurface(carContext, emptyList())

    init {
        lifecycle.addObserver(this)
        appManager.setSurfaceCallback(mapSurface)
        mapSurface.setDarkMode(resolveDarkMode())
        mapSurface.setControlCallbacks(
            GoViaCarMapSurface.ControlCallbacks(
                onOverlayAction = { action -> handleOverlayAction(action) },
            )
        )
        refreshOverlay()
    }

    override fun onResume(owner: LifecycleOwner) {
        appManager.setSurfaceCallback(mapSurface)
        mapSurface.setDarkMode(resolveDarkMode())
        refreshOverlay()
        invalidate()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        appManager.setSurfaceCallback(null)
        mapSurface.close()
    }

    override fun onGetTemplate(): Template {
        mapSurface.setDarkMode(resolveDarkMode())
        refreshOverlay()
        if (carContext.carAppApiLevel >= 7) {
            // Modern hosts: surface-only map template with no host action strip.
            // GoVia draws and handles every visible Home control itself.
            val emptyContent = PaneTemplate.Builder(Pane.Builder().build()).build()
            return MapWithContentTemplate.Builder()
                .setContentTemplate(emptyContent)
                .build()
        }

        // Compatibility fallback for older hosts where NavigationTemplate requires
        // an action strip. This path is not used by current DHU / Car API 7+.
        val requiredActionStrip = ActionStrip.Builder()
            .addAction(Action.APP_ICON)
            .build()
        return NavigationTemplate.Builder()
            .setActionStrip(requiredActionStrip)
            .build()
    }

    private fun refreshOverlay() {
        val state = repo.readState()
        val active = state.activeTripId
            ?.let { id -> state.trips.firstOrNull { it.id == id } }
        mapSurface.updateHomeOverlay(
            GoViaCarCockpitOverlayView.HomeState(
                activeTripName = active?.name?.let(::clean),
                recordingActive = repo.isRecording(),
            )
        )
    }

    private fun handleOverlayAction(action: GoViaCarCockpitOverlayView.Control) {
        when (action) {
            GoViaCarCockpitOverlayView.Control.HOME_TRIPS ->
                screenManager.push(GoViaCarTripsScreen(carContext))

            GoViaCarCockpitOverlayView.Control.HOME_RECORD ->
                screenManager.push(GoViaCarRecordScreen(carContext))

            GoViaCarCockpitOverlayView.Control.HOME_CONTINUE -> {
                val state = repo.readState()
                val active = state.activeTripId
                    ?.let { id -> state.trips.firstOrNull { it.id == id } }
                if (active != null) screenManager.push(GoViaCarNavigationScreen(carContext, active))
            }

            else -> Unit
        }
    }

    private fun clean(value: String): String = value
        .removePrefix("Her · ")
        .removeSuffix(", Norway")
        .replace(Regex("\\s+"), " ")
        .trim()
        .ifBlank { "Aktiv tur" }
        .take(48)

    private fun resolveDarkMode(): Boolean = when (repo.readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> carContext.isDarkMode
    }
}
