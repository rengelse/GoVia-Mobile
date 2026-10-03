import '../../../core/network/api_client.dart';
import '../../../domain/models.dart';
import '../domain/discovery_categories.dart';

class MapPlace {
  const MapPlace({required this.id, required this.name, required this.point,
    required this.category, this.tags = const {}});
  final String id;
  final String name;
  final GeoPoint point;
  final String category;
  final Map<String, String> tags;
}

class MapPlaceRepository {
  MapPlaceRepository(this.api);
  final ApiClient api;
  final Map<String, ({DateTime at, List<MapPlace> places})> _cache = {};

  Future<List<MapPlace>> around(GeoPoint point, DiscoveryCategory category, StageTransport transport) async {
    if (category.poiCategory == null || category.osmFilters.isEmpty) return const [];
    final key = '${transport.name}:${category.id}:${point.lat.toStringAsFixed(2)}:${point.lon.toStringAsFixed(2)}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 15)) return cached.places;
    Map<String, dynamic> data;
    if (!category.strictOsm) {
      final elements = <dynamic>[];
      var fallback = false;
      for (final type in category.poiTypes.isEmpty ? [category.poiType] : category.poiTypes) {
        final response = await api.postJson('/api/v1/map/poi/around', {
          'coord': [point.lon, point.lat], 'category': category.poiCategory,
          'type': type, 'radius': 5000, 'limit': category.poiTypes.isEmpty ? 50 : 25,
          'profile': switch (transport) {
            StageTransport.cycling => 'bicycle', StageTransport.walking => 'hiking',
            StageTransport.train => 'rail', _ => transport.name,
          },
        }).timeout(const Duration(seconds: 25));
        final result = unwrap(response);
        if (result['ok'] == false && result['useOverpassFallback'] != true) {
          throw StateError(result['userError']?.toString() ?? 'Kunne ikke hente steder.');
        }
        if (result['useOverpassFallback'] == true) { fallback = true; break; }
        if (result['elements'] is List) elements.addAll(result['elements'] as List);
      }
      data = fallback ? await _overpass(point, category) : {'elements': elements};
    } else {
      // Specialty labels require explicit source tags, never generic hotel results.
      data = await _overpass(point, category);
    }
    final places = parse(data, category);
    if (_cache.length >= 24) _cache.remove(_cache.keys.first);
    _cache[key] = (at: DateTime.now(), places: places);
    return places;
  }

  Future<Map<String, dynamic>> _overpass(GeoPoint point, DiscoveryCategory category) async {
    final area = '(around:5000,${point.lat.toStringAsFixed(5)},${point.lon.toStringAsFixed(5)})';
    final parts = category.osmFilters.map((filter) => 'nwr$filter$area;').join();
    return unwrap(await api.postJson('/api/v1/map/overpass', {
      'query': '[out:json][timeout:18];($parts);out tags center 50;',
    }).timeout(const Duration(seconds: 70)));
  }

  static Map<String, dynamic> unwrap(Map<String, dynamic> response) =>
      response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : response;

  static List<MapPlace> parse(Map<String, dynamic> response, DiscoveryCategory category) {
    final data = unwrap(response);
    final raw = data['elements'];
    if (raw is! List) return const [];
    final places = <MapPlace>[];
    final seen = <String>{};
    for (final row in raw.whereType<Map>()) {
      final centre = row['center'] is Map ? row['center'] as Map : row;
      final lat = double.tryParse(centre['lat'].toString());
      final lon = double.tryParse(centre['lon'].toString());
      if (lat == null || lon == null || !lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) continue;
      final tags = {for (final entry in (row['tags'] is Map ? row['tags'] as Map : const {}).entries)
        entry.key.toString(): entry.value.toString()};
      if (category.id == 'mc_hotel' && tags['motorcycle_friendly'] != 'yes') continue;
      if (category.id == 'bike_stay' && tags['bicycle_friendly'] != 'yes') continue;
      final name = tags['name']?.trim() ?? '';
      if (name.isEmpty) continue;
      final id = '${row['type'] ?? 'node'}:${row['id'] ?? '$lat,$lon'}';
      if (!seen.add(id)) continue;
      places.add(MapPlace(id: id, name: name, point: GeoPoint(lat: lat, lon: lon), category: category.label, tags: tags));
      if (places.length >= 50) break;
    }
    return places;
  }
}
