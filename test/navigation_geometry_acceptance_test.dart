import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';

void main() {
  Stage stageFor(RouteCandidate route) => Stage(
        id: 'stage-geometry',
        day: 1,
        order: 0,
        start: 'A',
        end: 'B',
        transport: StageTransport.car,
        routeCandidates: [route],
        officialRouteId: route.id,
      );

  NavigationManeuver maneuver(String id, int sequence, GeoPoint location, int expected) => NavigationManeuver(
        id: id,
        sequence: sequence,
        type: 'turn',
        modifier: sequence.isEven ? 'right' : 'left',
        instruction: 'Maneuver $id',
        location: location,
        distanceFromStartMeters: expected,
      );

  test('crossing route anchors repeated coordinate occurrences monotonically', () {
    const crossing = GeoPoint(lat: 60.0, lon: 5.0);
    final route = RouteCandidate(
      id: 'crossing',
      name: 'Crossing',
      distanceMeters: 4000,
      durationSeconds: 400,
      geometry: const [
        crossing,
        GeoPoint(lat: 60.006, lon: 5.006),
        GeoPoint(lat: 60.012, lon: 5.0),
        GeoPoint(lat: 60.006, lon: 4.994),
        crossing,
        GeoPoint(lat: 59.994, lon: 5.006),
      ],
      maneuvers: [
        maneuver('first', 0, crossing, 10),
        maneuver('second', 1, crossing, 3000),
      ],
      official: true,
    );
    final canonical = NavigationRoute.fromStage(stageFor(route), route);
    expect(canonical.maneuvers[1].shapeIndex, greaterThanOrEqualTo(canonical.maneuvers[0].shapeIndex));
    expect(canonical.maneuvers[1].routeProgressMeters, greaterThan(canonical.maneuvers[0].routeProgressMeters));
  });

  test('same road out and back uses expected progress to select later occurrence', () {
    const geometry = [
      GeoPoint(lat: 60.0, lon: 5.0),
      GeoPoint(lat: 60.01, lon: 5.0),
      GeoPoint(lat: 60.0, lon: 5.0),
    ];
    const point = GeoPoint(lat: 60.005, lon: 5.0);
    final early = routeProgressForPoint(point, geometry, expectedProgressMeters: 500);
    final late = routeProgressForPoint(point, geometry, expectedProgressMeters: 1700);
    expect(late, greaterThan(early + 500));
  });

  test('serpentine and parallel segments keep route position locally stable', () {
    const geometry = [
      GeoPoint(lat: 60.0000, lon: 5.0000),
      GeoPoint(lat: 60.0020, lon: 5.0040),
      GeoPoint(lat: 60.0040, lon: 5.0002),
      GeoPoint(lat: 60.0060, lon: 5.0042),
      GeoPoint(lat: 60.0080, lon: 5.0004),
      GeoPoint(lat: 60.0100, lon: 5.0044),
    ];
    const p1 = GeoPoint(lat: 60.0041, lon: 5.0003);
    const p2 = GeoPoint(lat: 60.0061, lon: 5.0041);
    final first = routeProgressForPoint(p1, geometry, expectedProgressMeters: 900);
    final second = routeProgressForPoint(p2, geometry, expectedProgressMeters: 1400);
    expect(second, greaterThan(first));
  });

  test('complex intersection maneuver anchors remain ordered', () {
    const geometry = [
      GeoPoint(lat: 60.000, lon: 5.000),
      GeoPoint(lat: 60.003, lon: 5.000),
      GeoPoint(lat: 60.003, lon: 5.004),
      GeoPoint(lat: 60.003, lon: 5.000),
      GeoPoint(lat: 60.006, lon: 5.000),
    ];
    final route = RouteCandidate(
      id: 'intersection',
      name: 'Intersection',
      distanceMeters: 2000,
      durationSeconds: 200,
      geometry: geometry,
      maneuvers: [
        maneuver('enter', 0, geometry[1], 300),
        maneuver('return', 1, geometry[3], 1300),
        maneuver('leave', 2, geometry[4], 1900),
      ],
      official: true,
    );
    final canonical = NavigationRoute.fromStage(stageFor(route), route);
    for (var i = 1; i < canonical.maneuvers.length; i++) {
      expect(canonical.maneuvers[i].routeProgressMeters, greaterThanOrEqualTo(canonical.maneuvers[i - 1].routeProgressMeters));
    }
  });
}
