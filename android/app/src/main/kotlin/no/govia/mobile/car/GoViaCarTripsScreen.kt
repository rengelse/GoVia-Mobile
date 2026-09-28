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

/** Native Android Auto trip browser. No custom surface controls or app-drawn tabs. */
class GoViaCarTripsScreen(
    carContext: CarContext,
    private val runtime: GoViaCarRuntime,
) : Screen(carContext) {

    private var activeTab = TAB_PLANNED

    override fun onGetTemplate(): Template {
        runtime.mapSurface.updateRoute(emptyList())
        runtime.mapSurface.setDisplayMode(GoViaCarMapSurface.DisplayMode.BROWSE)

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
            .addTab(tab(TAB_TOOLS, "Mer", R.drawable.ic_car_tools))
            .setActiveTabContentId(activeTab)
            .setTabContents(TabContents.Builder(listFor(activeTab)).build())
            .build()
    }

    private fun listFor(tabId: String): ListTemplate = when (tabId) {
        TAB_TOOLS -> toolsList()
        else -> tripList(tabId)
    }

    private fun tripList(tabId: String): ListTemplate {
        val wanted = when (tabId) {
            TAB_ACTIVE -> "active"
            TAB_COMPLETED -> "completed"
            else -> "planned"
        }
        val trips = GoViaCarRepository(carContext).readState().trips
            .filter { it.status == wanted }
            .sortedBy { it.name.lowercase(Locale.getDefault()) }

        val items = ItemList.Builder().setNoItemsMessage(
            when (wanted) {
                "active" -> "Ingen aktive turer"
                "completed" -> "Ingen fullførte turer"
                else -> "Ingen planlagte turer"
            },
        )
        trips.forEach { trip -> items.addItem(tripRow(trip, includeStatus = false)) }
        return ListTemplate.Builder().setSingleList(items.build()).build()
    }

    private fun toolsList(): ListTemplate {
        val items = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle("Søk destinasjon")
                    .addText("Finn adresse eller sted og start navigasjon")
                    .setImage(carIcon(R.drawable.ic_car_search))
                    .setBrowsable(true)
                    .setOnClickListener { screenManager.push(GoViaCarSearchScreen(carContext, runtime)) }
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle("Ta opp tur")
                    .addText("Registrer turen du faktisk kjører")
                    .setImage(carIcon(R.drawable.ic_car_record))
                    .setBrowsable(true)
                    .setOnClickListener { screenManager.push(GoViaCarRecordScreen(carContext, runtime)) }
                    .build(),
            )
        return ListTemplate.Builder().setSingleList(items.build()).build()
    }

    private fun legacyTemplate(): ListTemplate {
        val trips = GoViaCarRepository(carContext).readState().trips
            .sortedWith(compareBy<CarTrip> { statusRank(it.status) }.thenBy { it.name.lowercase(Locale.getDefault()) })
        val items = ItemList.Builder().setNoItemsMessage("Ingen GoVia-turer funnet")
        items.addItem(
            Row.Builder()
                .setTitle("Søk destinasjon")
                .setImage(carIcon(R.drawable.ic_car_search))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(GoViaCarSearchScreen(carContext, runtime)) }
                .build(),
        )
        items.addItem(
            Row.Builder()
                .setTitle("Ta opp tur")
                .setImage(carIcon(R.drawable.ic_car_record))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(GoViaCarRecordScreen(carContext, runtime)) }
                .build(),
        )
        trips.forEach { trip -> items.addItem(tripRow(trip, includeStatus = true)) }
        return ListTemplate.Builder()
            .setTitle("GoVia")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(items.build())
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
            .setOnClickListener { screenManager.push(GoViaCarTripDetailScreen(carContext, trip, runtime)) }
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

    private fun clean(value: String): String = value.replace(Regex("\\s+"), " ").trim().ifBlank { "Tur" }.take(44)

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
        private const val TAB_TOOLS = "tools"
    }
}
