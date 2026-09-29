import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_session.dart';

void main() {
  test('navigation runtime retains stage and route identity independently', () {
    const route = RouteCandidate(id: 'route-7', name: 'Rute', distanceMeters: 1000, durationSeconds: 100, geometry: [GeoPoint(lat: 60, lon: 5), GeoPoint(lat: 60.01, lon: 5)], maneuvers: [NavigationManeuver(id: 'm', sequence: 0, type: 'continue', instruction: 'Fortsett', location: GeoPoint(lat: 60.005, lon: 5), distanceFromStartMeters: 500)]);
    const stage = Stage(id: 'stage-3', day: 3, order: 0, start: 'A', end: 'B', transport: StageTransport.car, routeCandidates: [route], officialRouteId: 'route-7');
    final canonical = NavigationRoute.fromStage(stage, route);
    expect(canonical.stageId, 'stage-3');
    expect(canonical.routeId, 'route-7');
  });
}
