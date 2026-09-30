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
import android.util.Log
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

        if (state == null || state.rerouting) {
            builder.setNavigationInfo(RoutingInfo.Builder().setLoading(true).build())
        } else {
            val currentStep = when {
                state.arrived -> androidx.car.app.navigation.model.Step.Builder("Du er fremme")
                    .setManeuver(androidx.car.app.navigation.model.Maneuver.Builder(androidx.car.app.navigation.model.Maneuver.TYPE_DESTINATION).build())
                    .build()
                state.currentStep != null -> state.currentStep
                else -> androidx.car.app.navigation.model.Step.Builder("Følg ruten")
                    .setManeuver(androidx.car.app.navigation.model.Maneuver.Builder(androidx.car.app.navigation.model.Maneuver.TYPE_STRAIGHT).build())
                    .build()
            }
            val stepDistance = if (state.arrived) 0.0 else if (state.currentStep != null) state.distanceToStepMeters else state.remainingMeters
            val distinctNextStep = state.nextStep?.takeIf { next ->
                next.cue.toString().trim().lowercase() != currentStep.cue.toString().trim().lowercase()
            }
            val info = RoutingInfo.Builder()
                .setCurrentStep(currentStep, displayDistance(stepDistance))
                .apply { if (!state.arrived) distinctNextStep?.let(::setNextStep) }
                .build()
            builder.setNavigationInfo(info)
            state.destinationEstimate?.let { builder.setDestinationTravelEstimate(it) }
        }

        val template = builder.build()
        val info = template.navigationInfo as? RoutingInfo
        Log.i(
            GUIDANCE_DIAG_TAG,
            "template api=${carContext.carAppApiLevel} state=${state != null} rerouting=${state?.rerouting} " +
                "current=${info?.currentStep?.cue ?: "none"} distance=${info?.currentDistance} " +
                "next=${info?.nextStep?.cue ?: "none"} estimate=${template.destinationTravelEstimate != null}",
        )
        return template
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
        .addAction(cameraModeAction())
        .build()

    private fun cameraModeAction(): Action {
        val icon = when (mapSurface.currentNavigationCameraMode()) {
            GoViaCarMapSurface.NavigationCameraMode.PERSPECTIVE -> R.drawable.ic_car_camera_perspective
            GoViaCarMapSurface.NavigationCameraMode.NORTH_UP -> R.drawable.ic_car_camera_north_up
            GoViaCarMapSurface.NavigationCameraMode.OVERVIEW -> R.drawable.ic_car_camera_overview
        }
        return iconAction(icon) {
            mapSurface.cycleNavigationCameraMode()
            invalidate()
        }
    }

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

    companion object {
        private const val GUIDANCE_DIAG_TAG = "GoViaCarGuidanceDiag"
    }

}
