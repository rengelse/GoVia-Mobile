import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_session.dart';

void main() {
  Stage stageFor(RouteCandidate route, {String id = 'stage-1'}) => Stage(
        id: id,
        day: 1,
        order: 0,
        start: 'A',
        end: 'B',
        transport: StageTransport.car,
        routeCandidates: [route],
        officialRouteId: route.id,
      );

  RouteCandidate straightRoute({String id = 'route-1'}) => RouteCandidate(
        id: id,
        name: 'Test',
        distanceMeters: 1112,
        durationSeconds: 100,
        geometry: const [
          GeoPoint(lat: 60.0, lon: 5.0),
          GeoPoint(lat: 60.01, lon: 5.0),
        ],
        maneuvers: const [
          NavigationManeuver(
            id: 'm1',
            sequence: 0,
            type: 'continue',
            instruction: 'Fortsett',
            location: GeoPoint(lat: 60.005, lon: 5.0),
            distanceFromStartMeters: 556,
          ),
        ],
      );

  NavigationSession sessionFor(RouteCandidate route, {String stageId = 'stage-1'}) {
    final stage = stageFor(route, id: stageId);
    return NavigationSession(NavigationRoute.fromStage(stage, route));
  }

  test('projects a credible fix onto route progress', () {
    final session = sessionFor(straightRoute());
    final state = session.update(NavigationFix(
      lat: 60.005,
      lon: 5.0,
      speedMetersPerSecond: 10,
      accuracyMeters: 8,
      timestamp: DateTime(2026, 1, 1, 12),
    ));
    expect(state.offRouteDistanceMeters, lessThan(5));
    expect(state.progressMeters, greaterThan(500));
    expect(state.remainingMeters, inInclusiveRange(500, 620));
    expect(state.matchedPoint, isNotNull);
  });

  test('reports off-route distance and does not expose distant matched point', () {
    final session = sessionFor(straightRoute());
    final state = session.update(NavigationFix(
      lat: 60.005,
      lon: 5.01,
      speedMetersPerSecond: 10,
      accuracyMeters: 8,
      timestamp: DateTime(2026, 1, 1, 12),
    ));
    expect(state.offRouteDistanceMeters, greaterThan(140));
    expect(state.matchedPoint, isNull);
  });

  test('arrival requires three credible fixes and is terminal', () {
    final session = sessionFor(straightRoute());
    final base = DateTime(2026, 1, 1, 12);
    NavigationSessionState fix(double lat, int second) => session.update(NavigationFix(
          lat: lat,
          lon: 5.0,
          speedMetersPerSecond: 0,
          accuracyMeters: 8,
          timestamp: base.add(Duration(seconds: second)),
        ));
    expect(fix(60.01, 1).arrived, isFalse);
    expect(fix(60.01, 2).arrived, isFalse);
    final arrived = fix(60.01, 3);
    expect(arrived.arrived, isTrue);
    final after = fix(60.008, 4);
    expect(after.arrived, isTrue);
    expect(after.progressMeters, arrived.progressMeters);
  });

  test('stale timestamp is rejected without changing progress', () {
    final session = sessionFor(straightRoute());
    final base = DateTime(2026, 1, 1, 12);
    final first = session.update(NavigationFix(
      lat: 60.002, lon: 5.0, speedMetersPerSecond: 8, accuracyMeters: 8, timestamp: base.add(const Duration(seconds: 2)),
    ));
    final stale = session.update(NavigationFix(
      lat: 60.0025, lon: 5.0, speedMetersPerSecond: 8, accuracyMeters: 8, timestamp: base.add(const Duration(seconds: 1)),
    ));
    expect(stale.progressMeters, first.progressMeters);
    expect(stale.currentFix?.timestamp, first.currentFix?.timestamp);
  });

  test('poor first fix cannot create progress or arrival state', () {
    final session = sessionFor(straightRoute());
    final state = session.update(NavigationFix(
      lat: 60.01,
      lon: 5.0,
      speedMetersPerSecond: 0,
      accuracyMeters: 150,
      timestamp: DateTime(2026, 1, 1, 12),
    ));
    expect(state.gpsQuality, NavigationGpsQuality.poor);
    expect(state.progressMeters, 0);
    expect(state.arrived, isFalse);
  });

  test('replaceRoute cannot change active Stage identity', () {
    final original = straightRoute(id: 'route-a');
    final session = sessionFor(original, stageId: 'stage-a');
    final other = straightRoute(id: 'route-b');
    final otherStage = stageFor(other, id: 'stage-b');
    expect(
      () => session.replaceRoute(NavigationRoute.fromStage(otherStage, other)),
      throwsStateError,
    );
  });

  test('route preferences serialize deterministically', () {
    const preferences = RoutePreferences(avoidMotorways: true, avoidTolls: true, preferScenic: true);
    final json = preferences.toJson();
    expect(json['avoidMotorways'], isTrue);
    expect(json['avoidTolls'], isTrue);
    expect(json['preferScenic'], isTrue);
    expect(RoutePreferences.fromJson(json).avoidMotorways, isTrue);
  });

  test('good fix after poor first fix initializes progress normally', () {
    final session = sessionFor(straightRoute());
    final base = DateTime(2026, 1, 1, 12);
    final poor = session.update(NavigationFix(
      lat: 60.009,
      lon: 5.0,
      speedMetersPerSecond: 0,
      accuracyMeters: 150,
      timestamp: base,
    ));
    expect(poor.progressMeters, 0);
    final recovered = session.update(NavigationFix(
      lat: 60.005,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 1)),
    ));
    expect(recovered.progressMeters, greaterThan(500));
  });

  test('older good fix after newer poor fix is rejected as out of order', () {
    final session = sessionFor(straightRoute());
    final base = DateTime(2026, 1, 1, 12);
    final first = session.update(NavigationFix(
      lat: 60.002,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 1)),
    ));
    final poor = session.update(NavigationFix(
      lat: 60.003,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 150,
      timestamp: base.add(const Duration(seconds: 3)),
    ));
    expect(poor.progressMeters, first.progressMeters);
    final outOfOrder = session.update(NavigationFix(
      lat: 60.006,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 2)),
    ));
    expect(outOfOrder.progressMeters, first.progressMeters);
    expect(outOfOrder.currentFix?.timestamp, poor.currentFix?.timestamp);
  });

  test('rejected teleport cannot accumulate false arrival', () {
    final session = sessionFor(straightRoute());
    final base = DateTime(2026, 1, 1, 12);
    final initial = session.update(NavigationFix(
      lat: 60.001,
      lon: 5.0,
      speedMetersPerSecond: 0,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 1)),
    ));
    expect(initial.arrived, isFalse);
    NavigationSessionState teleport(int second) => session.update(NavigationFix(
          lat: 60.01,
          lon: 5.0,
          speedMetersPerSecond: 0,
          accuracyMeters: 8,
          timestamp: base.add(Duration(seconds: second)),
        ));
    expect(teleport(2).arrived, isFalse);
    expect(teleport(3).arrived, isFalse);
    final third = teleport(4);
    expect(third.arrived, isFalse);
    expect(third.progressMeters, initial.progressMeters);
  });

  test('duplicate timestamp is rejected even when previous fix was poor', () {
    final session = sessionFor(straightRoute());
    final base = DateTime(2026, 1, 1, 12);
    session.update(NavigationFix(
      lat: 60.002,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 1)),
    ));
    final poor = session.update(NavigationFix(
      lat: 60.003,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 150,
      timestamp: base.add(const Duration(seconds: 2)),
    ));
    final duplicate = session.update(NavigationFix(
      lat: 60.006,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 2)),
    ));
    expect(duplicate.progressMeters, poor.progressMeters);
    expect(duplicate.currentFix?.timestamp, poor.currentFix?.timestamp);
  });

  test('snapshot roundtrip restores runtime and timestamp continuity', () {
    final route = straightRoute();
    final session = sessionFor(route);
    final base = DateTime(2026, 1, 1, 12);
    final before = session.update(NavigationFix(
      lat: 60.004,
      lon: 5.0,
      speedMetersPerSecond: 10,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 2)),
    ));
    final encoded = session.snapshot().toJson();
    final restored = sessionFor(route);
    restored.restore(NavigationSessionSnapshot.fromJson(encoded));
    expect(restored.state?.progressMeters, closeTo(before.progressMeters, .01));
    expect(restored.state?.matchedSegmentIndex, before.matchedSegmentIndex);
    final stale = restored.update(NavigationFix(
      lat: 60.008,
      lon: 5.0,
      speedMetersPerSecond: 10,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 1)),
    ));
    expect(stale.progressMeters, closeTo(before.progressMeters, .01));
  });

  test('reroute keeps plannedRoute and replaces only activeRoute', () {
    final original = straightRoute(id: 'route-planned');
    final session = sessionFor(original);
    final rerouted = RouteCandidate(
      id: 'route-active',
      name: 'Reroute',
      distanceMeters: 900,
      durationSeconds: 80,
      geometry: const [
        GeoPoint(lat: 60.0, lon: 5.0),
        GeoPoint(lat: 60.008, lon: 5.001),
      ],
      maneuvers: original.maneuvers,
      official: true,
    );
    session.replaceRoute(NavigationRoute.fromStage(stageFor(rerouted), rerouted));
    expect(session.plannedRoute.routeId, 'route-planned');
    expect(session.activeRoute.routeId, 'route-active');
    expect(session.plannedRoute.stageId, session.activeRoute.stageId);
  });

  test('poor first fix does not bias projection continuity on recovery', () {
    final route = RouteCandidate(
      id: 'crossing-route',
      name: 'Crossing',
      distanceMeters: 2500,
      durationSeconds: 250,
      geometry: const [
        GeoPoint(lat: 60.000, lon: 5.000),
        GeoPoint(lat: 60.005, lon: 5.005),
        GeoPoint(lat: 60.010, lon: 5.000),
        GeoPoint(lat: 60.005, lon: 4.995),
        GeoPoint(lat: 60.000, lon: 5.000),
        GeoPoint(lat: 59.995, lon: 5.005),
      ],
      maneuvers: const [],
      official: true,
    );
    final session = NavigationSession(NavigationRoute.fromStage(stageFor(route), route));
    final base = DateTime(2026, 1, 1, 12);
    session.update(NavigationFix(
      lat: 59.997,
      lon: 5.003,
      speedMetersPerSecond: 0,
      accuracyMeters: 150,
      timestamp: base,
    ));
    final good = session.update(NavigationFix(
      lat: 59.996,
      lon: 5.004,
      speedMetersPerSecond: 8,
      headingDegrees: 140,
      accuracyMeters: 8,
      timestamp: base.add(const Duration(seconds: 1)),
    ));
    expect(good.progressMeters, greaterThan(1800));
  });

}
