import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/domain/transport_profiles.dart';

void main() {
  test('all core GoVia transports have profiles', () {
    for (final transport in StageTransport.values) {
      expect(profilesForTransport(transport), isNotEmpty, reason: '$transport must have at least one profile');
    }
  });

  test('motorcycle-only curvy profiles do not leak into car', () {
    expect(profilesForTransport(StageTransport.motorcycle).map((e) => e.id), contains('curvy'));
    expect(profilesForTransport(StageTransport.car).map((e) => e.id), isNot(contains('curvy')));
  });

  test('routing modes are transport aware', () {
    expect(routeModeForTransport(StageTransport.motorcycle), 'driving');
    expect(routeModeForTransport(StageTransport.car), 'driving');
    expect(routeModeForTransport(StageTransport.walking), 'walking');
    expect(routeModeForTransport(StageTransport.cycling), 'cycling');
    expect(routeModeForTransport(StageTransport.train), 'rail');
    expect(routeModeForTransport(StageTransport.ferry), 'ferry');
  });

  test('published route requires a transport type', () {
    const route = PublishedRoute(
      id: 'r1',
      title: 'Kysttur',
      authorName: 'Test',
      transport: StageTransport.cycling,
      start: 'A',
      end: 'B',
      distanceMeters: 10000,
      durationSeconds: 3600,
    );
    expect(route.transport, StageTransport.cycling);
  });
}
