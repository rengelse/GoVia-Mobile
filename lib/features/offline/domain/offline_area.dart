import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../domain/models.dart';

class OfflineArea {
  const OfflineArea({required this.name, required this.south, required this.west,
    required this.north, required this.east, this.maxZoom = 13, this.tripId});
  final String name;
  final double south, west, north, east;
  final double maxZoom;
  final String? tripId;
  static const maxTiles = 30000;
  bool get valid => name.trim().isNotEmpty && [south, west, north, east, maxZoom].every((v) => v.isFinite) &&
    south >= -85 && north <= 85 && south < north && west >= -180 && east <= 180 && west < east && maxZoom >= 5 && maxZoom <= 15;
  int get estimatedTiles {
    if (!valid) return maxTiles + 1;
    var count = 0;
    double y(double lat, int zoom) => (1 - math.log(math.tan(lat * math.pi / 180) + 1 / math.cos(lat * math.pi / 180)) / math.pi) / 2 * math.pow(2, zoom);
    for (var z = 5; z <= maxZoom.floor(); z++) {
      final scale = math.pow(2, z);
      final width = ((east + 180) / 360 * scale).floor() - ((west + 180) / 360 * scale).floor() + 1;
      final height = y(south, z).floor() - y(north, z).floor() + 1;
      count += width * height;
      if (count > maxTiles) break;
    }
    return count;
  }
  OfflineRegionDefinition definition(String style) => OfflineRegionDefinition(
    bounds: LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
    mapStyleUrl: style, minZoom: 5, maxZoom: maxZoom);

  static RouteCandidate? _official(Stage stage) =>
    stage.routeCandidates.where((r) => r.id == stage.officialRouteId).firstOrNull ??
    stage.routeCandidates.where((r) => r.official).firstOrNull;

  static List<GeoPoint> officialGeometry(Trip trip) {
    final stages = [...trip.stages]..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    final points = <GeoPoint>[];
    for (final stage in stages) {
      final official = _official(stage);
      if (official != null) { points.addAll(official.geometry); }
    }
    return points;
  }

  factory OfflineArea.forTrip(Trip trip, {double detailZoom = 13}) {
    if (trip.stages.any((stage) => (_official(stage)?.geometry.length ?? 0) < 2)) {
      throw StateError('En etappe mangler offisiell rute. Synkroniser eller beregn alle etappene først.');
    }
    final geometry = officialGeometry(trip);
    if (geometry.length < 2 || geometry.any((p) => !p.lat.isFinite || !p.lon.isFinite || p.lat.abs() > 85 || p.lon.abs() > 180)) {
      throw StateError('Turen mangler gyldig offisiell rute. Synkroniser eller beregn ruten først.');
    }
    final south = math.max(-85.0, geometry.map((p) => p.lat).reduce(math.min) - .16);
    final north = math.min(85.0, geometry.map((p) => p.lat).reduce(math.max) + .16);
    final west = math.max(-180.0, geometry.map((p) => p.lon).reduce(math.min) - .16);
    final east = math.min(180.0, geometry.map((p) => p.lon).reduce(math.max) + .16);
    if (east - west > 180) throw StateError('Ruten krysser datolinjen. Velg mindre kartområder manuelt.');
    var zoom = detailZoom;
    OfflineArea area() => OfflineArea(name: trip.name, tripId: trip.id, south: south, west: west, north: north, east: east, maxZoom: zoom);
    while (zoom > 5 && area().estimatedTiles > maxTiles) { zoom--; }
    return area();
  }
}
