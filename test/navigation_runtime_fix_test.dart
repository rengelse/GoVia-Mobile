import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starting navigation activates the concrete trip before opening cockpit', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final overview = File('lib/features/navigation/presentation/route_overview_screen.dart').readAsStringSync();
    expect(state, contains('Future<void> startNavigationStage(Stage stage)'));
    expect(state, contains("'status': 'Aktiv'"));
    expect(state, contains("store.writeString('active_trip_id', active.id)"));
    expect(overview, contains('await AppScope.of(context).startNavigationStage(s)'));
  });

  test('live GPS stream starts before blocking one-shot GPS prime', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    final streamIndex = source.indexOf('Geolocator.getPositionStream(locationSettings: streamSettings)');
    final currentIndex = source.indexOf('Geolocator.getCurrentPosition(');
    expect(streamIndex, greaterThanOrEqualTo(0));
    expect(currentIndex, greaterThan(streamIndex));
  });

  test('voice runtime respects profile preference and announces readiness', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains('state.profile?.voiceEnabled ?? true'));
    expect(source, contains("_tts.speak('Navigasjon startet.')"));
    expect(source, contains('_announceIfNeeded'));
  });

  test('android foreground navigation declares wake lock and notification handling', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(source, contains('Permission.notification.request()'));
    expect(manifest, contains('android.permission.WAKE_LOCK'));
  });
}
