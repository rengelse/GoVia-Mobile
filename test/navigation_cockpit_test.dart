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

  test('navigation performs route matching and controlled rerouting', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains('_matchToRoute'));
    expect(source, contains('_distanceFromRoute'));
    expect(source, contains('_offRouteFixes < 3'));
    expect(source, contains("postJson('/api/v1/map/route'"));
    expect(source, contains('Duration(seconds: 25)'));
    expect(source, contains('Beregner ny rute'));
  });
}
