import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('provider speed limit sections preserve path-index anchoring', () {
    final sections = RouteSpeedLimitSection.fromRouteJson({
      'speedLimitSections': [
      {
        'startDistanceMeters': 0,
        'endDistanceMeters': 500,
        'speedLimitKph': 80,
        'startPathIndex': 0,
        'endPathIndex': 3,
        'source': 'tomtom',
        'confidence': 1.0,
      },
      ],
    }, const [
      GeoPoint(lat: 60.0, lon: 10.0),
      GeoPoint(lat: 60.001, lon: 10.001),
      GeoPoint(lat: 60.002, lon: 10.002),
      GeoPoint(lat: 60.003, lon: 10.003),
    ]);
    expect(sections, hasLength(1));
    expect(sections.single.speedLimitKph, 80);
    expect(sections.single.startPathIndex, 0);
    expect(sections.single.endPathIndex, 3);
    expect(sections.single.source, 'tomtom');
  });
}
