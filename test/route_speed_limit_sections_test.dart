import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';

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

  test('active speed limit follows half-open route-progress ranges and clears in gaps', () {
    const sections = [
      RouteSpeedLimitSection(startDistanceMeters: 0, endDistanceMeters: 1000, speedLimitKph: 50),
      RouteSpeedLimitSection(startDistanceMeters: 1000, endDistanceMeters: 2400, speedLimitKph: 80),
      RouteSpeedLimitSection(startDistanceMeters: 3000, endDistanceMeters: 3800, speedLimitKph: 60),
    ];

    expect(speedLimitSectionForProgress(sections, 0)?.speedLimitKph, 50);
    expect(speedLimitSectionForProgress(sections, 999.9)?.speedLimitKph, 50);
    expect(speedLimitSectionForProgress(sections, 1000)?.speedLimitKph, 80);
    expect(speedLimitSectionForProgress(sections, 2399.9)?.speedLimitKph, 80);
    expect(speedLimitSectionForProgress(sections, 2400), isNull);
    expect(speedLimitSectionForProgress(sections, 2999.9), isNull);
    expect(speedLimitSectionForProgress(sections, 3000)?.speedLimitKph, 60);
    expect(speedLimitSectionForProgress(sections, double.nan), isNull);
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
