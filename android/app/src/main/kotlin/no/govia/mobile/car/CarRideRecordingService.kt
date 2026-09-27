package no.govia.mobile.car

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import no.govia.mobile.R
import org.json.JSONArray
import org.json.JSONObject

class CarRideRecordingService : Service(), LocationListener {
    companion object {
        const val ACTION_START = "no.govia.mobile.car.RECORD_START"
        const val ACTION_STOP = "no.govia.mobile.car.RECORD_STOP"
        private const val CHANNEL_ID = "govia_car_recording"
        private const val NOTIFICATION_ID = 42027
    }

    private lateinit var locationManager: LocationManager
    private val points = mutableListOf<Location>()
    private var startedAt: Long = 0L

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopAndPersist()
            else -> startRecording()
        }
        return START_NOT_STICKY
    }

    private fun startRecording() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            GoViaCarRepository(this).setRecording(false)
            stopSelf()
            return
        }
        if (startedAt != 0L) return
        startedAt = System.currentTimeMillis()
        GoViaCarRepository(this).setRecording(true)
        startForeground(
            NOTIFICATION_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_car_record)
                .setContentTitle("GoVia tar opp tur")
                .setContentText("GPS-sporet lagres lokalt til opptaket stoppes.")
                .setOngoing(true)
                .build()
        )
        runCatching { locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1500L, 5f, this) }
        runCatching { locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 3000L, 10f, this) }
    }

    private fun stopAndPersist() {
        runCatching { locationManager.removeUpdates(this) }
        GoViaCarRepository(this).setRecording(false)
        if (startedAt != 0L && points.size >= 2) {
            val payload = JSONObject()
                .put("id", "car-${System.currentTimeMillis()}")
                .put("startedAt", startedAt)
                .put("endedAt", System.currentTimeMillis())
                .put("points", JSONArray().apply {
                    points.forEach { location ->
                        put(JSONArray().put(location.longitude).put(location.latitude).put(location.time))
                    }
                })
            GoViaCarRepository(this).appendRecordedRide(payload.toString())
        }
        startedAt = 0L
        points.clear()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onLocationChanged(location: Location) {
        if (points.isEmpty() || points.last().distanceTo(location) >= 5f) points.add(Location(location))
    }

    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit
    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    override fun onDestroy() {
        if (startedAt != 0L) stopAndPersist()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "GoVia turoptak", NotificationManager.IMPORTANCE_LOW)
        )
    }
}
