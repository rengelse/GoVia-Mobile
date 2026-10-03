import 'dart:convert';

class MapHomePreferences {
  const MapHomePreferences({this.mapType = 'standard', this.activeTrip = true,
    this.publishedRoutes = false, this.favorites = false, this.completedTrips = false,
    this.places = true});
  final String mapType;
  final bool activeTrip;
  final bool publishedRoutes;
  final bool favorites;
  final bool completedTrips;
  final bool places;

  MapHomePreferences copyWith({String? mapType, bool? activeTrip, bool? publishedRoutes,
    bool? favorites, bool? completedTrips, bool? places}) => MapHomePreferences(
      mapType: mapType ?? this.mapType, activeTrip: activeTrip ?? this.activeTrip,
      publishedRoutes: publishedRoutes ?? this.publishedRoutes,
      favorites: favorites ?? this.favorites, completedTrips: completedTrips ?? this.completedTrips,
      places: places ?? this.places);

  Map<String, dynamic> toJson() => {'mapType': mapType, 'activeTrip': activeTrip,
    'publishedRoutes': publishedRoutes, 'favorites': favorites,
    'completedTrips': completedTrips, 'places': places};

  factory MapHomePreferences.fromJson(Map<String, dynamic>? data) {
    final type = data?['mapType'];
    return MapHomePreferences(
      mapType: const {'standard', 'terrain', 'satellite'}.contains(type) ? type as String : 'standard',
      activeTrip: data?['activeTrip'] is bool ? data!['activeTrip'] as bool : true,
      publishedRoutes: data?['publishedRoutes'] == true,
      favorites: data?['favorites'] == true,
      completedTrips: data?['completedTrips'] == true,
      places: data?['places'] is bool ? data!['places'] as bool : true,
    );
  }

  String style({required bool dark}) {
    if (mapType == 'standard') return dark
        ? 'https://tiles.openfreemap.org/styles/dark'
        : 'https://tiles.openfreemap.org/styles/liberty';
    final terrain = mapType == 'terrain';
    return jsonEncode({
      'version': 8,
      'sources': {'basemap': {
        'type': 'raster', 'tileSize': 256, 'minzoom': 0, 'maxzoom': terrain ? 17 : 19,
        'tiles': [terrain
          ? 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png'
          : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
        'attribution': terrain
          ? '© OpenStreetMap contributors, SRTM | © OpenTopoMap (CC-BY-SA)'
          : 'Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community',
      }},
      'layers': [{'id': 'basemap', 'type': 'raster', 'source': 'basemap',
        'paint': {'raster-fade-duration': 200}}],
    });
  }
}
