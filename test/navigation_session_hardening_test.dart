import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android navigation keeps GPS active through foreground location service', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains('AndroidSettings('));
    expect(source, contains('ForegroundNotificationConfig('));
    expect(source, contains("notificationTitle: 'GoVia navigerer'"));
    expect(source, contains('enableWakeLock: true'));
    expect(source, contains('setOngoing: true'));
  });

  test('arrival requires stable GPS fixes and changes stop action to complete', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains('_arrivalFixes >= 3'));
    expect(source, contains('distance <= 25'));
    expect(source, contains('distance <= 55 && speed <= 5'));
    expect(source, contains("'Fullfør tur'"));
    expect(source, contains("'Fullfør etappe'"));
    expect(source, contains("_tts.speak('Du er fremme.')"));
  });

  test('active navigation is rendered as a fullscreen map cockpit', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains('body: Stack('));
    expect(source, contains('NavigationMapCockpit('));
    expect(source, contains('controlsBottomInset: 205'));
    expect(source, isNot(contains('Expanded(\n              child: Padding(')));
  });

  test('completed final navigation is retained in mobile trip history', () {
    final source = File('lib/app/app_state.dart').readAsStringSync();
    expect(source, contains('completeNavigationStage'));
    expect(source, contains('TripStatus.completed'));
    expect(source, contains("store.writeJson('completed_trip_ids'"));
  });
}
