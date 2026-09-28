package no.govia.mobile.car

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import androidx.car.app.Session
import androidx.core.content.ContextCompat

/**
 * One Android Auto session owns one car runtime. Screens are native-template presentation only.
 */
class GoViaCarSession : Session() {
    private val runtime by lazy { GoViaCarRuntime(carContext, lifecycle) }

    override fun onCreateScreen(intent: Intent): Screen {
        val root = GoViaCarTripsScreen(carContext, runtime)
        val query = navigationQuery(intent)
        val target: Screen = if (query != null) GoViaCarSearchScreen(carContext, runtime, query) else root
        if (!hasLocationPermission()) {
            carContext.getCarService(ScreenManager::class.java).push(target)
            return GoViaCarLocationPermissionScreen(carContext) { target.invalidate() }
        }
        return target
    }

    override fun onNewIntent(intent: Intent) {
        val query = navigationQuery(intent) ?: return
        val manager = carContext.getCarService(ScreenManager::class.java)
        manager.popToRoot()
        manager.push(GoViaCarSearchScreen(carContext, runtime, query))
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(carContext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun navigationQuery(intent: Intent): String? {
        if (intent.action != CarContext.ACTION_NAVIGATE && intent.action != Intent.ACTION_VIEW) return null
        val data = intent.data ?: return null
        data.getQueryParameter("q")?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
        if (data.scheme != "geo") return null
        return coordinateQuery(data)
    }

    private fun coordinateQuery(uri: Uri): String? {
        val raw = uri.schemeSpecificPart.substringBefore('?').trim()
        if (raw.isBlank() || raw == "0,0") return null
        return raw.takeIf { COORDINATE_PATTERN.matches(it) }
    }

    companion object {
        private val COORDINATE_PATTERN = Regex("-?\\d{1,3}(?:\\.\\d+)?,-?\\d{1,3}(?:\\.\\d+)?")
    }
}
