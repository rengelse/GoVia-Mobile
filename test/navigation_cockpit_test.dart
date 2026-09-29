import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navigation cockpit follows heading and uses pitched camera', () {
    final source = File('lib/features/navigation/presentation/navigation_map_cockpit.dart').readAsStringSync();
    expect(source, contains('bearing: widget.heading'));
    expect(source, contains('tilt: 55'));
    expect(source, contains('lookAheadMeters'));
    expect(source, contains('speedKmh'));
    expect(source, contains('Sentrer på meg'));
  });

  test('Navigation Core v2 owns route matching and off-route state', () {
    final core = File('lib/features/navigation/domain/navigation_session.dart').readAsStringSync();
    final screen = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(core, contains('_bestProjection'));
    expect(core, contains('NavigationOffRouteState.offRoute'));
    expect(core, contains('headingDeltaDegrees'));
    expect(screen, contains('_sessionState?.rerouteRequired'));
    expect(screen, contains("postJson('/api/v1/map/route'"));
    expect(screen, contains('Duration(seconds: 25)'));
  });
}
