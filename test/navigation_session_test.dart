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
}
