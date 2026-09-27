import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discover phase 2 exposes local and global community routes', () {
    final source = File('lib/features/discover/presentation/discover_screen.dart').readAsStringSync();
    expect(source, contains("'Nær meg'"));
    expect(source, contains("'Globalt'"));
    expect(source, contains('Geolocator.getCurrentPosition'));
    expect(source, contains('_distanceMeters'));
    expect(source, contains('route.transport == StageTransport.ferry'));
  });

  test('discover phase 2 has real filters and no demo routes', () {
    final source = File('lib/features/discover/presentation/discover_screen.dart').readAsStringSync();
    expect(source, contains("'Filtrer turer'"));
    expect(source, contains("'Kun turer med bilder'"));
    expect(source, contains('maxDistanceKm'));
    expect(source, contains('maxDurationHours'));
    expect(source.toLowerCase(), isNot(contains('dummy')));
  });
}
