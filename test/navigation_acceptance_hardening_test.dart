import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_reroute_guard.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';

void main() {
  test('stale phone reroute request is rejected when any session identity changes', () {
    const request = NavigationRerouteRequestIdentity(
      tripId: 'trip-1',
      stageId: 'stage-1',
      routeId: 'route-1',
      sessionRevision: 7,
    );
    expect(
      request.matches(
        currentTripId: 'trip-1',
        currentStageId: 'stage-1',
        currentRouteId: 'route-1',
        currentSessionRevision: 7,
      ),
      isTrue,
    );
    expect(
      request.matches(
        currentTripId: 'trip-1',
        currentStageId: 'stage-2',
        currentRouteId: 'route-1',
        currentSessionRevision: 7,
      ),
      isFalse,
    );
    expect(
      request.matches(
        currentTripId: 'trip-1',
        currentStageId: 'stage-1',
        currentRouteId: 'route-2',
        currentSessionRevision: 8,
      ),
      isFalse,
    );
  });

  test('phone reroute reprojects waypoint progress onto replacement geometry', () {
    const waypoint = StageWaypoint(
      id: 'poi-1',
      name: 'Utsikt',
      kind: StageWaypointKind.poi,
      location: GeoPoint(lat: 60.004, lon: 5.0),
      distanceFromStartMeters: 900,
    );
    const geometry = [
      GeoPoint(lat: 60.0, lon: 5.0),
      GeoPoint(lat: 60.002, lon: 5.0),
      GeoPoint(lat: 60.004, lon: 5.0),
      GeoPoint(lat: 60.01, lon: 5.0),
    ];
    final reprojected = reprojectStageWaypoints(const [waypoint], geometry).single;
    expect(reprojected.id, waypoint.id);
    expect(reprojected.location, waypoint.location);
    expect(reprojected.distanceFromStartMeters, inInclusiveRange(420, 470));
  });
}
