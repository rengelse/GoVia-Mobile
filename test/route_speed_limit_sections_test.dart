import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  const geometry = [
    GeoPoint(lat: 60.0, lon: 5.0),
    GeoPoint(lat: 60.001, lon: 5.0),
    GeoPoint(lat: 60.002, lon: 5.0),
  ];

  test('parses provider offset and length speed-limit sections', () {
    final sections = RouteSpeedLimitSection.fromRouteJson({
      'speedLimitSections': [
        {'routeOffset': 0, 'length': 100, 'speedLimitInKmh': 50},
        {'routeOffset': 100, 'length': 200, 'speedLimit': {'kilometersPerHour': 80}},
      ],
    }, geometry);

    expect(sections, hasLength(2));
    expect(sections.first.speedLimitKph, 50);
    expect(sections.last.startDistanceMeters, 100);
    expect(sections.last.endDistanceMeters, 300);
    expect(sections.last.speedLimitKph, 80);
  });

  test('parses nested TomTom-style sections and point indexes', () {
    final sections = RouteSpeedLimitSection.fromRouteJson({
      'sections': {
        'speedLimitSections': [
          {'startPointIndex': 0, 'endPointIndex': 1, 'speedLimitKph': 30},
        ],
      },
    }, geometry);

    expect(sections, hasLength(1));
    expect(sections.single.startDistanceMeters, 0);
    expect(sections.single.endDistanceMeters, greaterThan(100));
    expect(sections.single.speedLimitKph, 30);
  });

  test('invalid and unknown speed limits are not promoted into UI data', () {
    final sections = RouteSpeedLimitSection.fromRouteJson({
      'speedLimitSections': [
        {'routeOffset': 0, 'length': 100, 'speedLimitInKmh': 0},
        {'routeOffset': 100, 'length': 100, 'speedLimitInKmh': 260},
        {'routeOffset': 200, 'speedLimitInKmh': 50},
      ],
    }, geometry);
    expect(sections, isEmpty);
  });
}
