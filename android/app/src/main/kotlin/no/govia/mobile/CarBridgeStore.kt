package no.govia.mobile

import android.content.Context
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile

/**
 * Small file-backed bridge shared by the Flutter UI process and the dedicated
 * Android Auto process. SharedPreferences is intentionally avoided here because
 * it is not a reliable cross-process synchronization primitive.
 */
class CarBridgeStore(context: Context) {
    private val dir = File(context.filesDir, "govia_car_bridge").apply { mkdirs() }
    private val stateFile = AtomicFile(File(dir, "state.json"))
    private val ridesFile = AtomicFile(File(dir, "recorded_rides.json"))
    private val ridesLock = File(dir, "recorded_rides.lock")
    private val legacyPrefs = context.getSharedPreferences("govia_car_bridge", Context.MODE_PRIVATE)

    init {
        migrateLegacyDataIfNeeded()
    }

    fun writeState(json: String) {
        writeAtomic(stateFile, json)
    }

    fun readState(): String? = readAtomic(stateFile)?.takeIf { it.isNotBlank() }

    fun appendRecordedRide(json: String) = withRideLock {
        val rides = runCatching { JSONArray(readAtomic(ridesFile) ?: "[]") }.getOrElse { JSONArray() }
        val ride = runCatching { JSONObject(json) }.getOrNull() ?: return@withRideLock
        rides.put(ride)
        writeAtomic(ridesFile, rides.toString())
    }

    fun drainRecordedRides(): String = withRideLock {
        val current = readAtomic(ridesFile)?.takeIf { it.isNotBlank() } ?: "[]"
        writeAtomic(ridesFile, "[]")
        current
    }

    private fun migrateLegacyDataIfNeeded() {
        if (!stateFile.baseFile.exists()) {
            legacyPrefs.getString("state_json", null)?.takeIf { it.isNotBlank() }?.let { writeAtomic(stateFile, it) }
        }
        if (!ridesFile.baseFile.exists()) {
            legacyPrefs.getString("recorded_rides_json", null)?.takeIf { it.isNotBlank() }?.let { writeAtomic(ridesFile, it) }
        }
    }

    private fun readAtomic(file: AtomicFile): String? = runCatching {
        file.openRead().bufferedReader(Charsets.UTF_8).use { it.readText() }
    }.getOrNull()

    private fun writeAtomic(file: AtomicFile, value: String) {
        val output = file.startWrite()
        try {
            output.write(value.toByteArray(Charsets.UTF_8))
            output.flush()
            file.finishWrite(output)
        } catch (t: Throwable) {
            file.failWrite(output)
            throw t
        }
    }

    private inline fun <T> withRideLock(block: () -> T): T {
        ridesLock.parentFile?.mkdirs()
        RandomAccessFile(ridesLock, "rw").channel.use { channel ->
            channel.lock().use { return block() }
        }
    }
}
