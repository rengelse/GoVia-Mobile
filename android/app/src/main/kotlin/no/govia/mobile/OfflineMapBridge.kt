package no.govia.mobile

import android.content.Context
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.offline.OfflineManager
import org.maplibre.android.offline.OfflineRegion

// Maintenance operations missing from the Flutter API; no navigation state is touched.
class OfflineMapBridge(private val context: Context) {
    private val retained = mutableMapOf<Long, OfflineRegion>()

    fun handle(method: String, id: Long?, result: MethodChannel.Result) {
        if (method == "release") { if (id != null) retained.remove(id); result.success(null); return }
        if (method != "resume" && method != "invalidate") { result.notImplemented(); return }
        if (id == null) { result.error("invalid_region", "Missing region id", null); return }
        OfflineManager.getInstance(context).listOfflineRegions(object : OfflineManager.ListOfflineRegionsCallback {
            override fun onList(offlineRegions: Array<OfflineRegion>?) {
                val region = offlineRegions?.firstOrNull { it.id == id }
                if (region == null) { result.error("missing_region", "Offline region not found", null); return }
                retained[id] = region
                try {
                    if (method == "resume") {
                        region.setDownloadState(OfflineRegion.STATE_ACTIVE)
                        result.success(null)
                    } else {
                        region.invalidate(object : OfflineRegion.OfflineRegionInvalidateCallback {
                            override fun onInvalidate() { result.success(null) }
                            override fun onError(error: String) { result.error("offline_invalidate", error, null) }
                        })
                    }
                } catch (error: Exception) { result.error("offline_maintenance", error.message, null) }
            }
            override fun onError(error: String) { result.error("offline_list", error, null) }
        })
    }
}
