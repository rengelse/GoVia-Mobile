package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Tab
import androidx.car.app.model.TabContents
import androidx.car.app.model.TabTemplate
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import no.govia.mobile.R
import java.util.Locale

class GoViaCarTripsScreen(carContext: CarContext) : Screen(carContext) {
    private var activeTab = TAB_PLANNED

    override fun onGetTemplate(): Template {
        if (carContext.carAppApiLevel < 6) return legacyTemplate()

        val callback = object : TabTemplate.TabCallback {
            override fun onTabSelected(tabContentId: String) {
                if (activeTab == tabContentId) return
                activeTab = tabContentId
                invalidate()
            }
        }

        return TabTemplate.Builder(callback)
            .setHeaderAction(Action.APP_ICON)
            .addTab(tab(TAB_PLANNED, "Planlagt", R.drawable.ic_car_planned))
            .addTab(tab(TAB_ACTIVE, "Aktiv", R.drawable.ic_car_active))
            .addTab(tab(TAB_COMPLETED, "Fullført", R.drawable.ic_car_completed))
            .setActiveTabContentId(activeTab)
            .setTabContents(TabContents.Builder(listFor(activeTab)).build())
            .build()
    }

    private fun listFor(tabId: String): ListTemplate {
        val wanted = when (tabId) {
            TAB_ACTIVE -> "active"
            TAB_COMPLETED -> "completed"
            else -> "planned"
        }
        val trips = GoViaCarRepository(carContext).readState().trips
            .filter { it.status == wanted }
            .sortedBy { it.name.lowercase(Locale.getDefault()) }

        val list = ItemList.Builder().setNoItemsMessage(
            when (wanted) {
                "active" -> "Ingen aktive turer"
                "completed" -> "Ingen fullførte turer"
                else -> "Ingen planlagte turer"
            }
        )

        trips.forEach { trip -> list.addItem(tripRow(trip, includeStatus = false)) }
        return ListTemplate.Builder().setSingleList(list.build()).build()
    }

    private fun legacyTemplate(): ListTemplate {
        val trips = GoViaCarRepository(carContext).readState().trips
            .sortedWith(compareBy<CarTrip> { statusRank(it.status) }.thenBy { it.name.lowercase(Locale.getDefault()) })
        val list = ItemList.Builder().setNoItemsMessage("Ingen GoVia-turer funnet")
        trips.forEach { trip -> list.addItem(tripRow(trip, includeStatus = true)) }
        return ListTemplate.Builder()
            .setTitle("Turer")
            .setHeaderAction(Action.BACK)
            .setSingleList(list.build())
            .build()
    }

    private fun tripRow(trip: CarTrip, includeStatus: Boolean): Row {
        val km = trip.totalDistanceMeters / 1000.0
        val minutes = (trip.totalDurationSeconds / 60).coerceAtLeast(1)
        val meta = buildList {
            add(String.format(Locale("nb", "NO"), "%.0f km", km))
            if (minutes >= 60) add("${minutes / 60} t ${minutes % 60} min") else add("$minutes min")
            if (trip.stages.size > 1) add("${trip.stages.size + 1} stopp")
        }.joinToString(" · ")

        return Row.Builder()
            .setTitle(clean(trip.name))
            .setImage(carIcon(R.drawable.ic_car_trips))
            .apply { if (includeStatus) addText(statusLabel(trip.status)) }
            .addText(meta)
            .setBrowsable(true)
            .setOnClickListener { screenManager.push(GoViaCarTripDetailScreen(carContext, trip)) }
            .build()
    }

    private fun tab(id: String, title: String, drawable: Int): Tab =
        Tab.Builder()
            .setTitle(title)
            .setContentId(id)
            .setIcon(carIcon(drawable))
            .build()

    private fun carIcon(drawable: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, drawable)).build()

    private fun clean(value: String): String = value
        .replace(Regex("\\s+"), " ")
        .trim()
        .ifBlank { "Tur" }
        .take(44)

    private fun statusRank(status: String): Int = when (status) {
        "active" -> 0
        "planned" -> 1
        "completed" -> 2
        else -> 3
    }

    private fun statusLabel(status: String): String = when (status) {
        "active" -> "Aktiv"
        "planned" -> "Planlagt"
        "completed" -> "Fullført"
        else -> "Tur"
    }

    companion object {
        private const val TAB_PLANNED = "planned"
        private const val TAB_ACTIVE = "active"
        private const val TAB_COMPLETED = "completed"
    }
}
