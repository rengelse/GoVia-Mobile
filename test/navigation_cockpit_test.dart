import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_session.dart';

void main() {
  test('off-route state belongs to session and requires repeated fixes', () {
    const route = RouteCandidate(id: 'r', name: 'R', distanceMeters: 1112, durationSeconds: 100, geometry: [GeoPoint(lat: 60, lon: 5), GeoPoint(lat: 60.01, lon: 5)], maneuvers: [NavigationManeuver(id: 'm', sequence: 0, type: 'continue', instruction: 'Fortsett', location: GeoPoint(lat: 60.005, lon: 5), distanceFromStartMeters: 556)]);
    const stage = Stage(id: 's', day: 1, order: 0, start: 'A', end: 'B', transport: StageTransport.car, routeCandidates: [route], officialRouteId: 'r');
    final session = NavigationSession(NavigationRoute.fromStage(stage, route));
    final base = DateTime(2026, 1, 1);
    NavigationSessionState fix(int n) => session.update(NavigationFix(lat: 60.005, lon: 5.01, speedMetersPerSecond: 10, accuracyMeters: 8, timestamp: base.add(Duration(seconds: n))));
    expect(fix(1).offRouteState, NavigationOffRouteState.suspect);
    expect(fix(2).offRouteState, NavigationOffRouteState.suspect);
    expect(fix(3).offRouteState, NavigationOffRouteState.offRoute);
  });
}
