package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class GoViaCarHomeScreen(carContext: CarContext, private val mapSurface: GoViaCarMapSurface) : Screen(carContext), DefaultLifecycleObserver {
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
        mapSurface.setDarkMode(resolveDarkMode())
        refreshOverlay()
        val requiredActionStrip = GoViaCarTemplateCompat.invisibleRequiredActionStrip()
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
                screenManager.push(GoViaCarTripsScreen(carContext, mapSurface))

            GoViaCarCockpitOverlayView.Control.HOME_RECORD ->
                screenManager.push(GoViaCarRecordScreen(carContext, mapSurface))

            GoViaCarCockpitOverlayView.Control.HOME_CONTINUE -> {
                val state = repo.readState()
                val active = state.activeTripId
                    ?.let { id -> state.trips.firstOrNull { it.id == id } }
                if (active != null) screenManager.push(GoViaCarNavigationScreen(carContext, active, mapSurface))
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
