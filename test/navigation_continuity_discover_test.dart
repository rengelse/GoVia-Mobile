import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discover uses horizontal route carousels without nearby truncation', () {
    final source = File('lib/features/discover/presentation/discover_screen.dart').readAsStringSync();
    expect(source, contains('scrollDirection: Axis.horizontal'));
    expect(source, contains('class _RouteCarousel'));
    expect(source, isNot(contains('_nearby(routes).take(10)')));
  });

  test('own trips can be deleted through owner-scoped trip repository', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final screen = File('lib/features/trips/presentation/trips_screen.dart').readAsStringSync();
    expect(state, contains("api.domain('trip', 'delete'"));
    expect(state, contains("'ownerId': user.id"));
    expect(state, contains('Bare tureier kan slette denne turen.'));
    expect(screen, contains('Slett tur'));
  });

  test('navigation primes GPS and Android supports picture in picture', () {
    final nav = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    final activity = File('android/app/src/main/kotlin/no/govia/mobile/MainActivity.kt').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(nav, contains('Geolocator.getLastKnownPosition()'));
    expect(nav, contains('Geolocator.getCurrentPosition('));
    expect(nav, contains('locationSettings: const LocationSettings('));
    expect(nav, contains('timeLimit: Duration(seconds: 15)'));
    expect(nav, contains('Geolocator.getPositionStream(locationSettings: streamSettings)'));
    expect(nav, contains("MethodChannel('no.govia.mobile/navigation')"));
    expect(activity, contains('enterPictureInPictureMode'));
    expect(activity, contains('onUserLeaveHint'));
    expect(manifest, contains('android:supportsPictureInPicture="true"'));
  });
}
