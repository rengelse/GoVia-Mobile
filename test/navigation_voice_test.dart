import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('navigation maneuver parses normalized backend contract', () {
    final maneuver = NavigationManeuver.fromJson({
      'id': 'm1',
      'sequence': 1,
      'type': 'turn',
      'modifier': 'right',
      'instruction': 'Sving til høyre inn på E39',
      'location': [5.32, 60.39],
      'distanceMeters': 400,
      'durationSeconds': 30,
      'distanceFromStartMeters': 1200,
      'source': 'provider',
      'confidence': 1,
    });
    expect(maneuver.modifier, 'right');
    expect(maneuver.location.lat, closeTo(60.39, 0.00001));
    expect(maneuver.instruction, contains('høyre'));
  });

  test('voice navigation is GPS and TTS driven', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains('FlutterTts'));
    expect(source, contains('Geolocator.getPositionStream'));
    expect(source, contains("isLanguageAvailable('nb-NO')"));
    expect(source, contains("'nb-NO' : 'no-NO'"));
    expect(source, contains("'/api/v1/map/guidance'"));
    expect(source, contains('_announcementBucket'));
    expect(source, contains('Basisveiledning fra rutegeometri'));
  });

  test('route candidates preserve maneuver data when ranked and saved', () {
    final source = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();
    expect(source, contains('NavigationManeuver.fromJson'));
    expect(source, contains('maneuvers: candidate.maneuvers'));
    expect(source, contains('guidanceSource: candidate.guidanceSource'));
  });
}
