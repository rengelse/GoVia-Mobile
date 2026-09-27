import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../domain/models.dart';

class OfflineMapService {
  static const styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  Future<OfflineRegion> downloadTripRegion({
    required String tripId,
    required String name,
    required List<GeoPoint> geometry,
    void Function(double progress, int bytes)? onProgress,
  }) async {
    if (geometry.length < 2) throw StateError('Turen mangler offisiell route geometry for offlinekart.');
    final minLat = geometry.map((p) => p.lat).reduce(math.min);
    final maxLat = geometry.map((p) => p.lat).reduce(math.max);
    final minLon = geometry.map((p) => p.lon).reduce(math.min);
    final maxLon = geometry.map((p) => p.lon).reduce(math.max);
    const padding = .16;
    final span = math.max(maxLat - minLat, maxLon - minLon);
    final maxZoom = span > 4 ? 10.5 : span > 2 ? 11.5 : 13.0;
    final definition = OfflineRegionDefinition(
      bounds: LatLngBounds(
        southwest: LatLng(minLat - padding, minLon - padding),
        northeast: LatLng(maxLat + padding, maxLon + padding),
      ),
      mapStyleUrl: styleUrl,
      minZoom: 5,
      maxZoom: maxZoom,
    );
    return downloadOfflineRegion(
      definition,
      metadata: {'tripId': tripId, 'name': name, 'type': 'govia-trip'},
      onEvent: (event) {
        if (event is InProgress) onProgress?.call(event.progress, event.completedResourceSize);
        if (event is Success) onProgress?.call(1, 0);
      },
    );
  }
}
