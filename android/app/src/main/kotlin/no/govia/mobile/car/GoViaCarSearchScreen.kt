package no.govia.mobile.car

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Template
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native Android Auto destination search. This screen is intentionally independent
 * of Flutter UI state: search, route calculation and preview happen inside the car session.
 */
class GoViaCarSearchScreen(carContext: CarContext, private val mapSurface: GoViaCarMapSurface) : Screen(carContext), SearchTemplate.SearchCallback {
    private data class PlaceResult(val label: String, val point: CarPoint)

    private val executor = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger(0)
    private val locationManager = carContext.getSystemService(LocationManager::class.java)
    private var query = ""
    private var loading = false
    private var errorMessage: String? = null
    private var results: List<PlaceResult> = emptyList()

    override fun onSearchTextChanged(searchText: String) {
        query = searchText.trim()
        errorMessage = null
        if (query.length < 2) {
            generation.incrementAndGet()
            results = emptyList()
            loading = false
            invalidate()
            return
        }
        performSearch(query)
    }

    override fun onSearchSubmitted(searchText: String) {
        query = searchText.trim()
        if (query.length >= 2) performSearch(query)
    }

    override fun onGetTemplate(): Template {
        val builder = SearchTemplate.Builder(this)
            .setHeaderAction(Action.BACK)
            .setSearchHint("Søk adresse eller sted")
            .setInitialSearchText(query)
            .setShowKeyboardByDefault(query.isBlank())

        if (loading) return builder.setLoading(true).build()

        val list = ItemList.Builder()
        errorMessage?.let { message ->
            list.addItem(Row.Builder().setTitle(message).addText("Prøv et annet søk").build())
        }
        results.forEach { result ->
            list.addItem(
                Row.Builder()
                    .setTitle(result.label.take(64))
                    .addText("Start navigasjon til dette stedet")
                    .setBrowsable(true)
                    .setOnClickListener { buildRouteAndPreview(result) }
                    .build()
            )
        }
        if (results.isEmpty() && errorMessage == null && query.length >= 2) {
            list.setNoItemsMessage("Ingen treff")
        }
        return builder.setItemList(list.build()).build()
    }

    override fun onDestroy() {
        generation.incrementAndGet()
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun performSearch(term: String) {
        val token = generation.incrementAndGet()
        loading = true
        results = emptyList()
        invalidate()
        executor.execute {
            val outcome = runCatching { geocode(term) }
            carContext.mainExecutor.execute {
                if (generation.get() != token) return@execute
                loading = false
                outcome.onSuccess {
                    results = it
                    errorMessage = null
                }.onFailure {
                    results = emptyList()
                    errorMessage = "Stedsøk feilet"
                }
                invalidate()
            }
        }
    }

    private fun buildRouteAndPreview(destination: PlaceResult) {
        val start = bestKnownLocation()
        if (start == null) {
            screenManager.push(
                object : Screen(carContext) {
                    override fun onGetTemplate(): Template = MessageTemplate.Builder("GoVia trenger posisjonen din for å beregne ruten.")
                        .setTitle("Posisjon mangler")
                        .setHeaderAction(Action.BACK)
                        .build()
                }
            )
            return
        }
        val token = generation.incrementAndGet()
        loading = true
        invalidate()
        executor.execute {
            val outcome = runCatching { route(start, destination) }
            carContext.mainExecutor.execute {
                if (generation.get() != token) return@execute
                loading = false
                outcome.onSuccess { trip -> screenManager.push(GoViaCarTripDetailScreen(carContext, trip, mapSurface)) }
                    .onFailure {
                        errorMessage = "Ruteberegning feilet"
                        invalidate()
                    }
            }
        }
    }

    private fun bestKnownLocation(): Location? {
        if (ContextCompat.checkSelfPermission(carContext, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return null
        val gps = runCatching { locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull()
        val network = runCatching { locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull()
        return listOfNotNull(gps, network).maxByOrNull { it.time }
    }

    private fun geocode(term: String): List<PlaceResult> {
        val payload = postJson("/api/v1/map/geocode", JSONObject().put("query", term))
        val features = payload.optJSONObject("data")?.optJSONArray("features") ?: JSONArray()
        val found = mutableListOf<PlaceResult>()
        val seen = mutableSetOf<String>()
        for (i in 0 until features.length()) {
            val feature = features.optJSONObject(i) ?: continue
            val coords = feature.optJSONObject("geometry")?.optJSONArray("coordinates") ?: continue
            if (coords.length() < 2) continue
            val props = feature.optJSONObject("properties") ?: JSONObject()
            val parts = listOf(
                props.optString("name"),
                props.optString("city").ifBlank { props.optString("town").ifBlank { props.optString("village") } },
                props.optString("state"),
                props.optString("country"),
            ).map { it.trim() }.filter { it.isNotEmpty() }
            val unique = parts.fold(mutableListOf<String>()) { acc, value ->
                if (acc.lastOrNull()?.equals(value, ignoreCase = true) != true) acc.add(value)
                acc
            }
            val label = unique.joinToString(", ").ifBlank { "Valgt sted" }
            val point = CarPoint(coords.optDouble(0), coords.optDouble(1))
            val key = "${label.lowercase()}|${point.lon}|${point.lat}"
            if (seen.add(key)) found.add(PlaceResult(label, point))
            if (found.size >= 6) break
        }
        return found
    }

    private fun route(start: Location, destination: PlaceResult): CarTrip {
        val points = JSONArray()
            .put(JSONObject().put("coord", JSONArray().put(start.longitude).put(start.latitude)).put("name", "Her"))
            .put(JSONObject().put("coord", JSONArray().put(destination.point.lon).put(destination.point.lat)).put("name", destination.label))
        val payload = postJson("/api/v1/map/route", JSONObject().put("points", points).put("mode", "driving"))
        val data = payload.optJSONObject("data") ?: error("Ugyldig rutesvar")
        val geometryJson = data.optJSONArray("geometry") ?: error("Ruten mangler geometri")
        val geometry = buildList {
            for (i in 0 until geometryJson.length()) {
                val p = geometryJson.optJSONArray(i) ?: continue
                if (p.length() >= 2) add(CarPoint(p.optDouble(0), p.optDouble(1)))
            }
        }
        require(geometry.size >= 2) { "Ruten mangler geometri" }
        val maneuversJson = data.optJSONArray("maneuvers") ?: JSONArray()
        val maneuvers = buildList {
            for (i in 0 until maneuversJson.length()) {
                val row = maneuversJson.optJSONObject(i) ?: continue
                val loc = row.optJSONArray("location")
                add(
                    CarManeuver(
                        id = row.optString("id", "search-maneuver-$i"),
                        sequence = row.optInt("sequence", i),
                        instruction = row.optString("instruction", "Fortsett"),
                        roadName = row.optString("roadName"),
                        distanceMeters = row.optInt("distanceMeters"),
                        distanceFromStartMeters = row.optInt("distanceFromStartMeters"),
                        location = if (loc != null && loc.length() >= 2) CarPoint(loc.optDouble(0), loc.optDouble(1)) else null,
                    )
                )
            }
        }.sortedBy { it.sequence }
        val now = System.currentTimeMillis()
        val stage = CarStage(
            id = "search-stage-$now",
            day = 0,
            order = 0,
            start = "Her",
            end = destination.label,
            transport = "driving",
            distanceMeters = data.optDouble("distance", 0.0).toInt(),
            durationSeconds = data.optDouble("duration", 0.0).toInt(),
            geometry = geometry,
            maneuvers = maneuvers,
        )
        return CarTrip(
            id = "search-trip-$now",
            name = destination.label,
            start = "Her",
            end = destination.label,
            status = "planned",
            stages = listOf(stage),
        )
    }

    private fun postJson(path: String, body: JSONObject): JSONObject {
        val connection = (URL("https://govia.no$path").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 10_000
            readTimeout = 15_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "GoVia-Mobile-AndroidAuto")
        }
        return try {
            connection.outputStream.bufferedWriter(Charsets.UTF_8).use { it.write(body.toString()) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (code !in 200..299) error("HTTP $code")
            JSONObject(text)
        } finally {
            connection.disconnect()
        }
    }
}
