import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_engine.dart';

void main() {
  test('navigation engine projects progress and remaining distance on route', () {
    final route = RouteCandidate(
      id: 'test',
      name: 'Test',
      distanceMeters: 1112,
      durationSeconds: 100,
      geometry: const [
        GeoPoint(lat: 60.0, lon: 5.0),
        GeoPoint(lat: 60.01, lon: 5.0),
      ],
    );
    final engine = GoViaNavigationEngine(route);
    final progress = engine.update(NavigationFix(
      lat: 60.005,
      lon: 5.0,
      speedMetersPerSecond: 10,
      timestamp: DateTime(2026, 1, 1, 12),
    ));

    expect(progress.offRouteDistanceMeters, lessThan(5));
    expect(progress.progressMeters, greaterThan(500));
    expect(progress.remainingMeters, greaterThan(500));
    expect(progress.remainingMeters, lessThan(620));
    expect(progress.matchedPoint, isNotNull);
  });

  test('navigation engine reports off-route distance and does not match distant fix', () {
    final route = RouteCandidate(
      id: 'test',
      name: 'Test',
      distanceMeters: 1112,
      durationSeconds: 100,
      geometry: const [
        GeoPoint(lat: 60.0, lon: 5.0),
        GeoPoint(lat: 60.01, lon: 5.0),
      ],
    );
    final progress = GoViaNavigationEngine(route).update(NavigationFix(
      lat: 60.005,
      lon: 5.01,
      speedMetersPerSecond: 10,
      timestamp: DateTime(2026, 1, 1, 12),
    ));

    expect(progress.offRouteDistanceMeters, greaterThan(140));
    expect(progress.matchedPoint, isNull);
  });

  test('route preferences serialize deterministically', () {
    const preferences = RoutePreferences(
      avoidMotorways: true,
      avoidTolls: true,
      preferScenic: true,
    );
    final json = preferences.toJson();
    expect(json['avoidMotorways'], isTrue);
    expect(json['avoidTolls'], isTrue);
    expect(json['preferScenic'], isTrue);
    expect(RoutePreferences.fromJson(json).avoidMotorways, isTrue);
  });
}
