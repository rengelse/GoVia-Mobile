import 'dart:convert';
import 'package:flutter/services.dart';
import 'offline_area.dart';

class OfflineCatalogArea {
  OfflineCatalogArea(Map<String, dynamic> json)
    : id = json['id'] as String, name = json['name'] as String,
      bounds = (json['bounds'] as List).cast<num>();
  final String id, name;
  final List<num> bounds;
  OfflineArea get area {
    var zoom = 13.0;
    OfflineArea candidate() => OfflineArea(name: name, west: bounds[0].toDouble(), south: bounds[1].toDouble(),
      east: bounds[2].toDouble(), north: bounds[3].toDouble(), maxZoom: zoom);
    while (zoom > 5 && candidate().estimatedTiles > OfflineArea.maxTiles) { zoom--; }
    return candidate();
  }
}
class OfflineCatalogCountry {
  OfflineCatalogCountry(Map<String, dynamic> json)
    : area = OfflineCatalogArea(json), continent = json['continent'] as String,
      regions = [for (final item in json['regions'] as List) OfflineCatalogArea(Map<String, dynamic>.from(item as Map))];
  final OfflineCatalogArea area;
  final String continent;
  final List<OfflineCatalogArea> regions;
}
Future<List<OfflineCatalogCountry>> loadOfflineCatalog() async {
  final json = jsonDecode(await rootBundle.loadString('assets/offline/catalog.json')) as Map<String, dynamic>;
  return [for (final country in json['countries'] as List) OfflineCatalogCountry(Map<String, dynamic>.from(country as Map))];
}
