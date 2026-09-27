import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Auto cockpit uses a real MapLibre map surface', () {
    final build = File('android/app/build.gradle').readAsStringSync();
    final surface = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarMapSurface.kt').readAsStringSync();
    expect(build, contains('org.maplibre.gl:android-sdk-opengl:13.6.1'));
    expect(surface, contains('MapView'));
    expect(surface, contains('createVirtualDisplay'));
    expect(surface, contains('https://tiles.openfreemap.org/styles/liberty'));
    expect(surface, contains('https://tiles.openfreemap.org/styles/dark'));
    expect(surface, contains('PolylineOptions'));
  });

  test('active navigation uses Android Auto native guidance over the map', () {
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    expect(navigation, contains('GoViaCarMapSurface'));
    expect(navigation, contains('NavigationTemplate.Builder'));
    expect(navigation, contains('setDestinationTravelEstimate'));
    expect(navigation, contains('setMapActionStrip'));
    expect(navigation, contains('Maneuver.TYPE_TURN_NORMAL_RIGHT'));
    expect(navigation, contains('looksLikeCoordinates'));
    expect(navigation, contains('showPoiAlert'));
    expect(navigation, contains('POI nærmer seg'));
  });

  test('recording opens real-map REC cockpit', () {
    final record = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordScreen.kt').readAsStringSync();
    final cockpit = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    expect(record, contains('GoViaCarRecordingCockpitScreen'));
    expect(cockpit, contains('GoViaCarMapSurface'));
    expect(cockpit, contains('recordingMode = true'));
    expect(cockpit, contains('Stopp og lagre'));
    expect(cockpit, contains('setMapActionStrip'));
  });

  test('trip detail uses map with content preview', () {
    final detail = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripDetailScreen.kt').readAsStringSync();
    expect(detail, contains('MapWithContentTemplate.Builder'));
    expect(detail, contains('GoViaCarMapSurface'));
    expect(detail, contains('Start tur'));
  });

  test('main branch CI exposes downloadable debug APK', () {
    final workflow = File('.github/workflows/android-release.yml').readAsStringSync();
    expect(workflow, contains('Upload debug APK artifact'));
    expect(workflow, contains('build/app/outputs/flutter-apk/app-debug.apk'));
  });

  test('Android Auto version marker bumped', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 0.1.31+32'));
  });
}
