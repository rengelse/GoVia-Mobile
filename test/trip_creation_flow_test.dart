import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current location resolves a human-readable place name', () {
    final source = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();
    expect(source, contains('_reverseGeocode'));
    expect(source, contains('nominatim.openstreetmap.org'));
    expect(source, contains("final displayName = placeName == null ? 'Her' : 'Her · \$placeName';"));
    expect(source, isNot(contains("label: 'Her · \${position.latitude")));
  });

  test('planned trip has direct save and start-now actions', () {
    final source = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();
    expect(source, contains("label: const Text('Lagre tur')"));
    expect(source, contains("label: const Text('Start nå')"));
    expect(source, contains('startNow: true'));
    expect(source, contains('AppRoutes.navigation'));
  });

  test('locally planned trips survive app restart with route geometry', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    expect(state, contains('local_trip_snapshots'));
    expect(state, contains('_persistLocalTripSnapshot'));
    expect(state, contains("'routeCandidates'"));
    expect(state, contains("'geometry'"));
    expect(state, contains("'maneuvers'"));
  });

  test('saved planned trip can start directly from trip detail', () {
    final detail = File('lib/features/trips/presentation/trip_detail_screen.dart').readAsStringSync();
    expect(detail, contains("label: const Text('Start tur')"));
    expect(detail, contains('startNavigationStage(first)'));
    expect(detail, contains('AppRoutes.navigation'));
  });
}
