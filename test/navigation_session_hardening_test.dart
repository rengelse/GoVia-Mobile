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

  test('Navigation Core v2 owns arrival and runtime session state', () {
    final core = File('lib/features/navigation/domain/navigation_session.dart').readAsStringSync();
    final screen = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(core, contains('class NavigationSession'));
    expect(core, contains('NavigationArrivalState.arrived'));
    expect(core, contains('_arrivalFixes >= 3'));
    expect(screen, contains("_tts.speak('Du er fremme.')"));
  });

  test('active navigation is rendered as a fullscreen map cockpit', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains('body: Stack('));
    expect(source, contains('NavigationMapCockpit('));
    expect(source, contains('controlsBottomInset: 205'));
  });

  test('completed final navigation is retained in mobile trip history', () {
    final source = File('lib/app/app_state.dart').readAsStringSync();
    expect(source, contains('completeNavigationStage'));
    expect(source, contains('TripStatus.completed'));
    expect(source, contains("store.writeJson('completed_trip_ids'"));
  });
}
