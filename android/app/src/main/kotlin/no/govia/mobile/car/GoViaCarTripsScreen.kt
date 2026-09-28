package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import java.util.Locale

class GoViaCarTripsScreen(carContext: CarContext, private val mapSurface: GoViaCarMapSurface) : Screen(carContext), DefaultLifecycleObserver {
    private val repo = GoViaCarRepository(carContext)
    private var activeTab = TAB_PLANNED
    private var visibleTrips: List<CarTrip> = emptyList()

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
        val wantedStatus = when (activeTab) {
            TAB_ACTIVE -> "active"
            TAB_COMPLETED -> "completed"
            else -> "planned"
        }
        visibleTrips = repo.readState().trips
            .filter { it.status == wantedStatus }
            .sortedBy { it.name.lowercase(Locale.getDefault()) }
            .take(MAX_VISIBLE_TRIPS)

        mapSurface.updateTripsOverlay(
            GoViaCarCockpitOverlayView.TripsState(
                activeTab = activeTab,
                trips = visibleTrips.map { trip ->
                    GoViaCarCockpitOverlayView.TripCard(
                        title = clean(trip.name),
                        meta = tripMeta(trip),
                    )
                },
            )
        )
    }

    private fun handleOverlayAction(action: GoViaCarCockpitOverlayView.Control) {
        when (action) {
            GoViaCarCockpitOverlayView.Control.BACK -> screenManager.pop()
            GoViaCarCockpitOverlayView.Control.TAB_PLANNED -> selectTab(TAB_PLANNED)
            GoViaCarCockpitOverlayView.Control.TAB_ACTIVE -> selectTab(TAB_ACTIVE)
            GoViaCarCockpitOverlayView.Control.TAB_COMPLETED -> selectTab(TAB_COMPLETED)
            GoViaCarCockpitOverlayView.Control.TAB_RECORD -> screenManager.push(GoViaCarRecordScreen(carContext, mapSurface))
            GoViaCarCockpitOverlayView.Control.TAB_SEARCH -> screenManager.push(GoViaCarSearchScreen(carContext, mapSurface))
            GoViaCarCockpitOverlayView.Control.TRIP_0 -> openTrip(0)
            GoViaCarCockpitOverlayView.Control.TRIP_1 -> openTrip(1)
            GoViaCarCockpitOverlayView.Control.TRIP_2 -> openTrip(2)
            GoViaCarCockpitOverlayView.Control.TRIP_3 -> openTrip(3)
            else -> Unit
        }
    }

    private fun selectTab(tab: String) {
        if (activeTab == tab) return
        activeTab = tab
        refreshOverlay()
        invalidate()
    }

    private fun openTrip(index: Int) {
        visibleTrips.getOrNull(index)?.let { trip ->
            screenManager.push(GoViaCarTripDetailScreen(carContext, trip, mapSurface))
        }
    }

    private fun tripMeta(trip: CarTrip): String {
        val km = trip.totalDistanceMeters / 1000.0
        val minutes = (trip.totalDurationSeconds / 60).coerceAtLeast(1)
        return buildList {
            add(String.format(Locale("nb", "NO"), "%.0f km", km))
            if (minutes >= 60) add("${minutes / 60} t ${minutes % 60} min") else add("$minutes min")
            if (trip.stages.size > 1) add("${trip.stages.size + 1} stopp")
        }.joinToString(" · ")
    }

    private fun clean(value: String): String = value
        .replace(Regex("\\s+"), " ")
        .trim()
        .ifBlank { "Tur" }
        .take(44)

    private fun resolveDarkMode(): Boolean = when (repo.readState().themeMode) {
        "light" -> false
        "dark" -> true
        else -> carContext.isDarkMode
    }

    companion object {
        private const val TAB_PLANNED = "planned"
        private const val TAB_ACTIVE = "active"
        private const val TAB_COMPLETED = "completed"
        private const val MAX_VISIBLE_TRIPS = 4
    }
}
