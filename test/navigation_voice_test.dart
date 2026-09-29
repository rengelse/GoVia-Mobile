import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('normalized maneuver contract preserves structured guidance semantics', () {
    final maneuver = NavigationManeuver.fromJson({'id': 'm1', 'sequence': 1, 'type': 'turn', 'modifier': 'right', 'instruction': 'Sving til høyre inn på E39', 'roadName': 'E39', 'roadRef': 'E39', 'location': [5.32, 60.39], 'distanceMeters': 400, 'durationSeconds': 30, 'distanceFromStartMeters': 1200, 'exit': 2, 'source': 'provider', 'confidence': 1});
    expect(maneuver.type, 'turn');
    expect(maneuver.modifier, 'right');
    expect(maneuver.roadRef, 'E39');
    expect(maneuver.exit, 2);
    expect(maneuver.confidence, 1);
  });
}
