import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop handoff redeems an authenticated exact trip snapshot', () {
    final appState = File('lib/app/app_state.dart').readAsStringSync();
    expect(appState, contains('Future<Trip> redeemDesktopHandoff(String rawCode)'));
    expect(appState, contains("api.domain('mobileHandoff', 'redeem', [token])"));
    expect(appState, contains('rowTripId != base.id'));
    expect(appState, contains("store.writeString('active_trip_id'"));
  });

  test('scanner consumes the handoff instead of showing the old placeholder', () {
    final screen = File('lib/features/group/presentation/invitation_screen.dart').readAsStringSync();
    expect(screen, contains('redeemDesktopHandoff'));
    expect(screen, isNot(contains('consume endpoint')));
    expect(screen, isNot(contains('backendkontrakt mangler')));
  });

  test('mobile version is v0.1.23', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 0.1.23+24'));
  });
}
