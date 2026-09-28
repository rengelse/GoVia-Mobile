package no.govia.mobile

import android.content.Context
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile

/**
 * Process-safe bridge between the Flutter phone process and the dedicated
 * Android Auto process. Android Auto must never depend on MainActivity being
 * alive, and phone UI work must never share the car display's main thread.
 */
class CarBridgeStore(context: Context) {
    private val dir = File(context.applicationContext.filesDir, "govia_car_bridge").apply { mkdirs() }
    private val stateFile = AtomicFile(File(dir, "state.json"))
    private val ridesFile = AtomicFile(File(dir, "recorded_rides.json"))
    private val stateLock = File(dir, "state.lock")
    private val ridesLock = File(dir, "recorded_rides.lock")
    private val legacyPrefs = context.applicationContext.getSharedPreferences("govia_car_bridge", Context.MODE_PRIVATE)

    init {
        migrateLegacyDataIfNeeded()
    }

    fun writeState(json: String) = withFileLock(stateLock) {
        writeAtomic(stateFile, json)
    }

    fun readState(): String? = withFileLock(stateLock) {
        readAtomic(stateFile)?.takeIf { it.isNotBlank() }
    }

    fun appendRecordedRide(json: String) = withFileLock(ridesLock) {
        val rides = runCatching { JSONArray(readAtomic(ridesFile) ?: "[]") }.getOrElse { JSONArray() }
        val ride = runCatching { JSONObject(json) }.getOrNull() ?: return@withFileLock
        rides.put(ride)
        writeAtomic(ridesFile, rides.toString())
    }

    fun drainRecordedRides(): String = withFileLock(ridesLock) {
        val current = readAtomic(ridesFile)?.takeIf { it.isNotBlank() } ?: "[]"
        writeAtomic(ridesFile, "[]")
        current
    }

    private fun migrateLegacyDataIfNeeded() {
        if (!stateFile.baseFile.exists()) {
            legacyPrefs.getString("state_json", null)?.takeIf { it.isNotBlank() }?.let {
                withFileLock(stateLock) { if (!stateFile.baseFile.exists()) writeAtomic(stateFile, it) }
            }
        }
        if (!ridesFile.baseFile.exists()) {
            legacyPrefs.getString("recorded_rides_json", null)?.takeIf { it.isNotBlank() }?.let {
                withFileLock(ridesLock) { if (!ridesFile.baseFile.exists()) writeAtomic(ridesFile, it) }
            }
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

    private inline fun <T> withFileLock(lockFile: File, block: () -> T): T {
        lockFile.parentFile?.mkdirs()
        RandomAccessFile(lockFile, "rw").channel.use { channel ->
            channel.lock().use { return block() }
        }
    }
}
