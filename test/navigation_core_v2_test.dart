import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_session.dart';

void main() {
  Stage stageWithRoute({int maneuverDistance = 900}) {
    const geometry = [
      GeoPoint(lat: 60.0, lon: 5.0),
      GeoPoint(lat: 60.005, lon: 5.0),
      GeoPoint(lat: 60.01, lon: 5.0),
    ];
    final route = RouteCandidate(
      id: 'route-1',
      name: 'Test',
      distanceMeters: 1112,
      durationSeconds: 100,
      geometry: geometry,
      official: true,
      guidanceSource: 'test',
      maneuvers: [
        NavigationManeuver(
          id: 'turn-1',
          sequence: 0,
          type: 'turn',
          modifier: 'right',
          instruction: 'Sving til høyre',
          location: geometry[1],
          distanceFromStartMeters: maneuverDistance,
        ),
      ],
    );
    return Stage(
      id: 'stage-1',
      day: 1,
      order: 1,
      start: 'Start',
      end: 'Mål',
      transport: StageTransport.car,
      routeCandidates: [route],
      officialRouteId: route.id,
    );
  }

  test('canonical maneuver is anchored to route geometry', () {
    final stage = stageWithRoute(maneuverDistance: 900);
    final route = NavigationRoute.fromStage(stage, stage.routeCandidates.single);
    expect(route.maneuvers.single.routeProgressMeters, inInclusiveRange(530, 580));
    expect(route.maneuvers.single.shapeIndex, inInclusiveRange(0, 1));
  });

  test('session owns exactly one stage and advances with credible GPS', () {
    final stage = stageWithRoute();
    final session = NavigationSession(NavigationRoute.fromStage(stage, stage.routeCandidates.single));
    final state = session.update(NavigationFix(
      lat: 60.004,
      lon: 5.0,
      speedMetersPerSecond: 10,
      headingDegrees: 0,
      accuracyMeters: 8,
      timestamp: DateTime(2026, 1, 1, 12),
    ));
    expect(state.route.stageId, stage.id);
    expect(state.progressMeters, greaterThan(400));
    expect(state.gpsQuality, NavigationGpsQuality.good);
  });

  test('poor GPS accuracy cannot jump navigation progress', () {
    final stage = stageWithRoute();
    final session = NavigationSession(NavigationRoute.fromStage(stage, stage.routeCandidates.single));
    final base = DateTime(2026, 1, 1, 12);
    final first = session.update(NavigationFix(
      lat: 60.001,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 8,
      timestamp: base,
    ));
    final poor = session.update(NavigationFix(
      lat: 60.009,
      lon: 5.0,
      speedMetersPerSecond: 8,
      accuracyMeters: 150,
      timestamp: base.add(const Duration(seconds: 1)),
    ));
    expect(poor.gpsQuality, NavigationGpsQuality.poor);
    expect(poor.progressMeters, first.progressMeters);
  });

  test('off-route state requires three repeated fixes', () {
    final stage = stageWithRoute();
    final session = NavigationSession(NavigationRoute.fromStage(stage, stage.routeCandidates.single));
    final base = DateTime(2026, 1, 1, 12);
    NavigationSessionState update(int seconds) => session.update(NavigationFix(
          lat: 60.005,
          lon: 5.01,
          speedMetersPerSecond: 10,
          accuracyMeters: 8,
          timestamp: base.add(Duration(seconds: seconds)),
        ));
    expect(update(1).offRouteState, NavigationOffRouteState.suspect);
    expect(update(2).offRouteState, NavigationOffRouteState.suspect);
    expect(update(3).offRouteState, NavigationOffRouteState.offRoute);
  });

  test('arrival requires three consecutive credible fixes', () {
    final stage = stageWithRoute();
    final session = NavigationSession(NavigationRoute.fromStage(stage, stage.routeCandidates.single));
    final base = DateTime(2026, 1, 1, 12);
    NavigationSessionState update(int seconds) => session.update(NavigationFix(
          lat: 60.01,
          lon: 5.0,
          speedMetersPerSecond: 0,
          accuracyMeters: 8,
          timestamp: base.add(Duration(seconds: seconds)),
        ));
    expect(update(1).arrived, isFalse);
    expect(update(2).arrived, isFalse);
    expect(update(3).arrived, isTrue);
  });
  test('loop maneuvers at same coordinate anchor to later occurrence in order', () {
    const a = GeoPoint(lat: 60.0, lon: 5.0);
    const b = GeoPoint(lat: 60.001, lon: 5.0);
    const c = GeoPoint(lat: 60.001, lon: 5.001);
    const geometry = [a, b, c, b, a];
    final candidate = RouteCandidate(
      id: 'loop-route',
      name: 'Loop',
      distanceMeters: 450,
      durationSeconds: 80,
      geometry: geometry,
      official: true,
      guidanceSource: 'test',
      maneuvers: const [
        NavigationManeuver(id: 'm1', sequence: 0, type: 'continue', instruction: 'Første', location: b, distanceFromStartMeters: 110),
        NavigationManeuver(id: 'm2', sequence: 1, type: 'turn', instruction: 'Andre', location: b, distanceFromStartMeters: 330),
      ],
    );
    final stage = Stage(id: 'loop-stage', day: 1, order: 1, start: 'A', end: 'A', transport: StageTransport.car, routeCandidates: [candidate], officialRouteId: candidate.id);
    final route = NavigationRoute.fromStage(stage, candidate);
    expect(route.maneuvers[1].routeProgressMeters, greaterThan(route.maneuvers[0].routeProgressMeters + 100));
  });

  test('unknown GPS accuracy cannot advance progress or trigger arrival', () {
    final stage = stageWithRoute();
    final session = NavigationSession(NavigationRoute.fromStage(stage, stage.routeCandidates.single));
    final state = session.update(NavigationFix(
      lat: 60.01,
      lon: 5.0,
      speedMetersPerSecond: 0,
      accuracyMeters: 0,
      timestamp: DateTime(2026, 1, 1, 12),
    ));
    expect(state.gpsQuality, NavigationGpsQuality.unknown);
    expect(state.progressMeters, 0);
    expect(state.arrived, isFalse);
  });

}
