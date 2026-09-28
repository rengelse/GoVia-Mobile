import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/map/route_render_key.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('route map render identity changes when geometry changes', () {
    const original = [
      GeoPoint(lat: 60.000000, lon: 5.000000),
      GeoPoint(lat: 60.010000, lon: 5.010000),
    ];
    const changed = [
      GeoPoint(lat: 60.000000, lon: 5.000000),
      GeoPoint(lat: 60.020000, lon: 5.020000),
    ];

    expect(
      routeRenderKey(original, const [], true, false),
      isNot(routeRenderKey(changed, const [], true, false)),
    );
  });

  test('route map render identity changes when visible waypoints change', () {
    const geometry = [
      GeoPoint(lat: 60.000000, lon: 5.000000),
      GeoPoint(lat: 60.010000, lon: 5.010000),
    ];
    const waypoint = StageWaypoint(
      id: 'poi-1',
      name: 'Utsikt',
      kind: StageWaypointKind.poi,
      location: GeoPoint(lat: 60.005000, lon: 5.005000),
    );

    expect(
      routeRenderKey(geometry, const [], true, false),
      isNot(routeRenderKey(geometry, const [waypoint], true, false)),
    );
  });

  test('selected route preserves every candidate and official geometry', () {
    final plan = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();
    expect(plan, contains('routeCandidates: candidates'));
    expect(plan, contains('official: candidate.id == route.id'));
    final profiles = File('lib/domain/transport_profiles.dart').readAsStringSync();
    expect(profiles, contains("label: 'Raskest'"));
    expect(profiles, contains("label: 'Balansert'"));
    expect(profiles, contains("label: 'Svingete'"));
    expect(profiles, contains("label: 'Maks svingete'"));
    expect(plan, contains('_curvatureScore'));
  });

  test('trip detail renders official route geometry', () {
    final trip = File('lib/features/trips/presentation/trip_detail_screen.dart').readAsStringSync();
    expect(trip, contains('points: _tripGeometry(stages)'));
    expect(trip, contains('candidate.id == stage.officialRouteId'));
  });
}
