package no.govia.mobile.car

import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Alert
import androidx.car.app.model.CarText
import androidx.car.app.model.Distance
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import no.govia.mobile.R

/**
 * Active navigation screen using the host-owned NavigationTemplate UI.
 * MapLibre draws map/route only; maneuver, ETA and controls are native Android Auto components.
 */
class GoViaCarNavigationScreen(
    carContext: CarContext,
    private val trip: CarTrip,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext), DefaultLifecycleObserver {

    private val mapSurface get() = runtime.mapSurface
    private val appManager = carContext.getCarService(AppManager::class.java)
    private var navigationState: GoViaNavigationService.State? = null
    private var lastPoiBanner: String? = null

    private val runtimeListener: (GoViaNavigationService.State) -> Unit = { state ->
        navigationState = state
        state.poiBanner?.takeIf { it != lastPoiBanner }?.let { banner ->
            lastPoiBanner = banner
            showPoiAlert(banner)
        }
        if (!state.navigating) {
            screenManager.popToRoot()
        } else {
            invalidate()
        }
    }

    init {
        lifecycle.addObserver(this)
    }

    override fun onStart(owner: LifecycleOwner) {
        mapSurface.updateRoute(trip.stages.flatMap { it.geometry })
        mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.NAVIGATION)
        mapSurface.setDarkMode(resolveDarkMode())
        runtime.startNavigation(trip, runtimeListener)
    }

    override fun onStop(owner: LifecycleOwner) {
        runtime.detachNavigationListener(runtimeListener)
    }

    override fun onGetTemplate(): Template {
        mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.NAVIGATION)
        mapSurface.setDarkMode(resolveDarkMode())

        val state = navigationState
        val builder = NavigationTemplate.Builder()
            .setBackgroundColor(GoViaCarBrand.ORANGE)
            .setActionStrip(mainActionStrip())

        if (carContext.carAppApiLevel >= 2) {
            builder.setMapActionStrip(mapActionStrip())
            builder.setPanModeListener { }
        }

        if (state == null || state.currentStep == null || state.rerouting) {
            builder.setNavigationInfo(RoutingInfo.Builder().setLoading(true).build())
        } else {
            val info = RoutingInfo.Builder()
                .setCurrentStep(state.currentStep, displayDistance(state.distanceToStepMeters))
                .apply { state.nextStep?.let(::setNextStep) }
                .build()
            builder.setNavigationInfo(info)
            state.destinationEstimate?.let { builder.setDestinationTravelEstimate(it) }
        }

        return builder.build()
    }

    private fun mainActionStrip(): ActionStrip = ActionStrip.Builder()
        .addAction(
            iconAction(R.drawable.ic_car_sound) {
                runtime.toggleVoiceMuted()
                invalidate()
            },
        )
        .addAction(
            Action.Builder()
                .setTitle("Avslutt")
                .setOnClickListener { requestStopConfirmation() }
                .build(),
        )
        .build()

    private fun mapActionStrip(): ActionStrip = ActionStrip.Builder()
        .addAction(Action.PAN)
        .addAction(iconAction(R.drawable.ic_car_recenter) { mapSurface.recenter() })
        .addAction(iconAction(R.drawable.ic_car_zoom_in) { mapSurface.zoomBy(1.0) })
        .addAction(iconAction(R.drawable.ic_car_zoom_out) { mapSurface.zoomBy(-1.0) })
        .build()

    private fun iconAction(drawable: Int, action: () -> Unit): Action = Action.Builder()
        .setIcon(GoViaCarBrand.icon(carContext, drawable))
        .setOnClickListener(action)
        .build()

    private fun requestStopConfirmation() {
        screenManager.push(
            GoViaCarEndTripConfirmScreen(carContext) {
                runtime.stopNavigation()
                screenManager.popToRoot()
            },
        )
    }

    private fun showPoiAlert(text: String) {
        if (carContext.carAppApiLevel < 5) return
        runCatching {
            appManager.showAlert(
                Alert.Builder(text.hashCode(), CarText.create(text.take(48)), 8_000L)
                    .setSubtitle(CarText.create("POI nærmer seg"))
                    .build(),
            )
        }
    }

    private fun displayDistance(meters: Double): Distance = if (meters >= 1000.0) {
        Distance.create(meters / 1000.0, Distance.UNIT_KILOMETERS_P1)
    } else {
        Distance.create(meters.coerceAtLeast(0.0), Distance.UNIT_METERS)
    }

    private fun resolveDarkMode(): Boolean = when (GoViaCarRepository(carContext).readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> carContext.isDarkMode
    }
}
