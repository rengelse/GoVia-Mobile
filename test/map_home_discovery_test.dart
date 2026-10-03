import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:govia_mobile/core/network/api_client.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/home/domain/discovery_categories.dart';
import 'package:govia_mobile/features/home/domain/map_home_preferences.dart';
import 'package:govia_mobile/features/home/data/map_place_repository.dart';
import 'package:govia_mobile/features/home/presentation/map_settings_sheet.dart';
import 'package:govia_mobile/features/home/presentation/map_overlay_renderer.dart';
import 'package:govia_mobile/features/new_trip/domain/plan_trip_request.dart';

void main() {
  PublishedRoute route(String id, StageTransport transport, {List<String> tags = const [], String title = 'Tur', String status = 'published', String visibility = 'public'}) => PublishedRoute(
    id: id, title: title, authorName: 'Test', transport: transport, start: 'A', end: 'B',
    distanceMeters: 1000, durationSeconds: 100, tags: tags, status: status, visibility: visibility);

  test('each transport has relevant categories and ferry is not a primary discovery mode', () {
    expect(discoveryCategories(StageTransport.motorcycle).map((c) => c.id), containsAll(['curves', 'passes', 'mc_hotel']));
    expect(discoveryCategories(StageTransport.car).map((c) => c.id), containsAll(['scenic', 'family']));
    expect(discoveryCategories(StageTransport.walking).map((c) => c.id), containsAll(['trails', 'nature']));
    expect(discoveryCategories(StageTransport.cycling).map((c) => c.id), containsAll(['cycle_routes', 'quiet', 'repair']));
    expect(discoveryCategories(StageTransport.train).map((c) => c.id), contains('stations'));
    expect(discoveryTransport(StageTransport.ferry), StageTransport.car);
    expect(discoveryCategories(StageTransport.car).any((c) => c.id == 'mc_hotel'), isFalse);
  });

  test('cards filter by transport and explicit tags, excluding drafts and private routes', () {
    final curves = discoveryCategories(StageTransport.motorcycle).firstWhere((c) => c.id == 'curves');
    final results = filterDiscoveryRoutes([
      route('mc', StageTransport.motorcycle, tags: ['Kurvekombinasjoner']),
      route('car', StageTransport.car, tags: ['kurver']),
      route('untagged', StageTransport.motorcycle, title: 'Svingete hotell'),
      route('draft', StageTransport.motorcycle, tags: ['kurver'], status: 'draft'),
      route('private', StageTransport.motorcycle, tags: ['kurver'], visibility: 'private'),
    ], StageTransport.motorcycle, curves);
    expect(results.map((r) => r.id), ['mc']);
    final hotel = discoveryCategories(StageTransport.motorcycle).firstWhere((c) => c.id == 'mc_hotel');
    expect(hotel.matchesRoute(route('generic', StageTransport.motorcycle, tags: ['hotel'])), isFalse);
    expect(hotel.matchesRoute(route('special', StageTransport.motorcycle, tags: ['MC-hotell'])), isTrue);
  });

  test('POI lookup uses configured provider then the server Overpass fallback', () async {
    final paths = <String>[];
    final category = discoveryCategories(StageTransport.walking).firstWhere((c) => c.id == 'views');
    final repo = MapPlaceRepository(ApiClient(client: MockClient((request) async {
      paths.add(request.url.path);
      final body = jsonDecode(request.body) as Map;
      if (request.url.path.endsWith('/around')) {
        expect(body['coord'], [5.32, 60.39]);
        expect(body['profile'], 'hiking');
        return http.Response(jsonEncode({'data': {'ok': false, 'useOverpassFallback': true}}), 200);
      }
      expect(body['query'], contains('["tourism"="viewpoint"]'));
      return http.Response(jsonEncode({'data': {'elements': [
        {'type': 'way', 'id': 1, 'center': {'lat': 60.4, 'lon': 5.33}, 'tags': {'name': 'Utsikten', 'tourism': 'viewpoint'}},
      ]}}), 200);
    })));
    final places = await repo.around(const GeoPoint(lat: 60.39, lon: 5.32), category, StageTransport.walking);
    expect(paths, ['/api/v1/map/poi/around', '/api/v1/map/overpass']);
    expect(places.single.point.lon, 5.33);
    await repo.around(const GeoPoint(lat: 60.39, lon: 5.32), category, StageTransport.walking);
    expect(paths, hasLength(2));
  });

  test('special hotel markers reject generic hotels and invalid coordinates', () {
    final category = discoveryCategories(StageTransport.motorcycle).firstWhere((c) => c.id == 'mc_hotel');
    final places = MapPlaceRepository.parse({'elements': [
      {'id': 1, 'lat': 60, 'lon': 5, 'tags': {'name': 'Vanlig hotell', 'tourism': 'hotel'}},
      {'id': 2, 'lat': 60, 'lon': 5, 'tags': {'name': 'MC-hotellet', 'motorcycle_friendly': 'yes'}},
      {'id': 3, 'lat': 95, 'lon': 5, 'tags': {'name': 'Ugyldig', 'motorcycle_friendly': 'yes'}},
    ]}, category);
    expect(places.map((p) => p.name), ['MC-hotellet']);
  });

  test('map preferences restore all layers and raster sources include attribution', () {
    final preferences = const MapHomePreferences().copyWith(mapType: 'terrain', activeTrip: false,
      publishedRoutes: true, favorites: true, completedTrips: true, places: false);
    final restored = MapHomePreferences.fromJson(jsonDecode(jsonEncode(preferences.toJson())) as Map<String, dynamic>);
    expect(restored.toJson(), preferences.toJson());
    expect(MapHomePreferences.fromJson({'mapType': 'broken', 'places': 42}).mapType, 'standard');
    expect(MapHomePreferences.fromJson({'places': 42}).places, isTrue);
    final terrain = jsonDecode(restored.style(dark: true)) as Map;
    expect(terrain['sources']['basemap']['maxzoom'], 17);
    expect(terrain['sources']['basemap']['attribution'], contains('OpenTopoMap'));
    final satellite = jsonDecode(restored.copyWith(mapType: 'satellite').style(dark: false)) as Map;
    expect(satellite['sources']['basemap']['tiles'].single, contains('/tile/{z}/{y}/{x}'));
  });

  test('home preview sampling preserves endpoints and canonical geometry', () {
    final points = [for (var i = 0; i < 1000; i++) GeoPoint(lat: 60 + i / 10000, lon: 5)];
    final sampled = mapPreviewGeometry(points);
    expect(sampled, hasLength(250));
    expect(sampled.first, points.first);
    expect(sampled.last, points.last);
    expect(points, hasLength(1000));
  });

  test('temporary planning transport overrides profile while default planning follows profile', () {
    expect(const PlanTripRequest(transport: StageTransport.walking).resolveTransport(StageTransport.motorcycle), StageTransport.walking);
    expect(const PlanTripRequest().resolveTransport(StageTransport.cycling), StageTransport.cycling);
    expect(const PlanTripRequest().resolveTransport(null), StageTransport.car);
    expect(const PlanTripRequest(transport: StageTransport.ferry).resolveTransport(null), StageTransport.car);
  });

  testWidgets('settings toggles update immediately and retain independent layer choices', (tester) async {
    MapHomePreferences? changed;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MapSettingsSheet(
      preferences: const MapHomePreferences(), onChanged: (value) => changed = value))));
    await tester.tap(find.text('Terreng'));
    await tester.pump();
    expect(changed!.mapType, 'terrain');
    await tester.tap(find.text('Favoritter'));
    await tester.pump();
    expect(changed!.favorites, isTrue);
    expect(changed!.mapType, 'terrain');
    expect(changed!.activeTrip, isTrue);
  });
}
