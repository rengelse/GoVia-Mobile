import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/core/storage/local_store.dart';
import 'package:govia_mobile/core/storage/offline_map_service.dart';
import 'package:govia_mobile/features/offline/domain/offline_area.dart';
import 'package:govia_mobile/features/offline/data/offline_map_controller.dart';

class FakeOfflineBackend implements OfflineBackend {
  final regions = <OfflineRegion>[];
  final ready = <int, bool>{};
  final paused = <int>[];
  final resumed = <int>[];
  final invalidated = <int>[];
  int creates = 0;
  bool completeOnCreate = true;
  @override
  Future<List<OfflineRegion>> list() async => [...regions];
  @override
  Future<OfflineRegionStatus> status(int id) async => OfflineRegionStatus(
    completedResourceCount: ready[id] == true ? 100 : 10, requiredResourceCount: 100,
    completedResourceSize: 1024, isComplete: ready[id] == true, downloadProgress: ready[id] == true ? 100 : 10);
  @override
  Future<OfflineRegion> create(OfflineRegionDefinition definition, Map<String, dynamic> metadata) async {
    final region = OfflineRegion(id: ++creates, definition: definition, metadata: metadata);
    regions.add(region); ready[region.id] = completeOnCreate; return region;
  }
  @override
  Future<void> pause(int id) async { paused.add(id); }
  @override
  Future<void> resume(int id) async { resumed.add(id); ready[id] = true; }
  @override
  Future<void> invalidate(int id) async { invalidated.add(id); }
  @override
  Future<void> delete(int id) async { regions.removeWhere((r) => r.id == id); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const area = OfflineArea(name: 'Bergen', south: 60.3, west: 5.2, north: 60.4, east: 5.4);

  test('area budget grows with detail and rejects invalid bounds/dateline selection', () {
    expect(area.valid, isTrue);
    final detailed = OfflineArea(name: area.name, south: area.south, west: area.west,
      north: area.north, east: area.east, maxZoom: 15);
    expect(detailed.estimatedTiles, greaterThan(area.estimatedTiles));
    expect(const OfflineArea(name: 'Invalid', south: 60, north: 61, west: 170, east: -170).valid, isFalse);
    expect(const OfflineArea(name: 'World', south: -80, west: -170, north: 80, east: 170, maxZoom: 15).estimatedTiles, greaterThan(OfflineArea.maxTiles));
  });

  test('trip download uses chosen official route and rejects missing stage geometry', () {
    const chosen = RouteCandidate(id: 'chosen', name: 'Valgt', distanceMeters: 100, durationSeconds: 10,
      geometry: [GeoPoint(lat: 60.3, lon: 5.2), GeoPoint(lat: 60.4, lon: 5.4)]);
    const stale = RouteCandidate(id: 'stale', name: 'Gammel', distanceMeters: 100, durationSeconds: 10, official: true,
      geometry: [GeoPoint(lat: 10, lon: 10), GeoPoint(lat: 11, lon: 11)]);
    const stage = Stage(id: 's', day: 0, order: 0, start: 'A', end: 'B', transport: StageTransport.walking,
      officialRouteId: 'chosen', routeCandidates: [chosen, stale]);
    Trip trip(List<Stage> stages) => Trip(id: 't', name: 'Tur', startDate: DateTime(2026), endDate: DateTime(2026),
      start: 'A', end: 'B', status: TripStatus.planned, stages: stages);
    expect(OfflineArea.officialGeometry(trip([stage])).first.lat, 60.3);
    expect(OfflineArea.forTrip(trip([stage])).south, greaterThan(60));
    expect(() => OfflineArea.forTrip(trip([stage, const Stage(id: 'missing', day: 1, order: 0,
      start: 'B', end: 'C', transport: StageTransport.walking)])), throwsStateError);
  });

  test('both themes download once and exact repeats do not delete or recreate regions', () async {
    SharedPreferences.setMockInitialValues({'offline_only_wifi': false});
    final backend = FakeOfflineBackend(); var notices = 0;
    final controller = OfflineMapController(await LocalStore.create(), backend: backend,
      pollInterval: const Duration(milliseconds: 1), onReady: (_, _) async { notices++; });
    await controller.download(area);
    expect(backend.creates, 2); expect(notices, 1);
    expect(controller.entries.every((e) => e.ready), isTrue);
    await controller.download(area);
    expect(backend.creates, 2); expect(notices, 1);
    controller.dispose();
  });

  test('creation does not claim ready until native completion; stop preserves partial regions', () async {
    SharedPreferences.setMockInitialValues({'offline_only_wifi': false});
    final backend = FakeOfflineBackend()..completeOnCreate = false;
    var notices = 0;
    final controller = OfflineMapController(await LocalStore.create(), backend: backend,
      pollInterval: const Duration(milliseconds: 1), onReady: (_, _) async { notices++; });
    final download = controller.download(area);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.busy, isTrue); expect(notices, 0);
    expect(controller.entries.single.ready, isFalse);
    await controller.stop(); await download;
    expect(backend.regions, hasLength(1)); expect(backend.paused, contains(1));
    expect(notices, 0); expect(controller.busy, isFalse);
    controller.dispose();
  });

  test('persisted regions restore and maintenance uses resume/invalidate rather than replacement', () async {
    SharedPreferences.setMockInitialValues({'offline_only_wifi': false});
    final backend = FakeOfflineBackend();
    await backend.create(area.definition(OfflineMapController.lightStyle), {'name': area.name});
    final controller = OfflineMapController(await LocalStore.create(), backend: backend);
    await controller.refresh();
    expect(controller.entries.single.ready, isTrue);
    await controller.update(controller.entries.single);
    expect(backend.invalidated, [1]); expect(backend.resumed, [1]); expect(backend.creates, 1);
    await controller.delete(controller.entries.single);
    expect(controller.entries, isEmpty); controller.dispose();
  });

  test('Wi-Fi-only blocks downloads before native creation and foreground loss pauses active work', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = FakeOfflineBackend()..completeOnCreate = false;
    final controller = OfflineMapController(await LocalStore.create(), backend: backend,
      pollInterval: const Duration(milliseconds: 1));
    await expectLater(controller.download(area), throwsStateError);
    expect(backend.creates, 0);
    controller.wifi = true;
    final download = controller.download(area);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.paused, isTrue); expect(backend.paused, contains(1));
    await controller.stop(); await download; controller.dispose();
  });
}
