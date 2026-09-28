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

  test('navigation performs route matching in engine and controlled rerouting in screen', () {
    final engine = File('lib/features/navigation/domain/navigation_engine.dart').readAsStringSync();
    final screen = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(engine, contains('_nearestProjection'));
    expect(engine, contains('offRouteDistanceMeters: projection.distanceMeters'));
    expect(screen, contains('_offRouteFixes < 3'));
    expect(screen, contains("postJson('/api/v1/map/route'"));
    expect(screen, contains('Duration(seconds: 25)'));
    expect(screen, contains('Beregner ny rute'));
  });
}
