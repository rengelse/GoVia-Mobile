import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Auto cockpit uses a real MapLibre map surface', () {
    final build = File('android/app/build.gradle').readAsStringSync();
    final surface = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarMapSurface.kt').readAsStringSync();
    expect(build, contains('org.maplibre.gl:android-sdk-opengl:13.6.1'));
    expect(surface, contains('MapView'));
    expect(surface, contains('createVirtualDisplay'));
    expect(surface, contains('LIGHT_STYLE'));
    expect(surface, contains('DARK_STYLE'));
    expect(surface, contains('PolylineOptions'));
    expect(surface, contains('routeCasingPolyline'));
  });

  test('active navigation uses responsive GoVia cockpit overlay instead of huge host routing card', () {
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    expect(navigation, contains('updateNavigationOverlay'));
    expect(navigation, contains('NavigationTemplate.Builder'));
    expect(navigation, isNot(contains('.setNavigationInfo(routingInfo)')));
    expect(overlay, contains('POI nærmer seg'));
    expect(overlay, contains('Opptak pågår'));
    expect(overlay, contains('drawTurnIcon'));
  });

  test('recording uses full-map REC cockpit without PaneTemplate content card', () {
    final record = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordScreen.kt').readAsStringSync();
    final cockpit = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    expect(record, contains('GoViaCarRecordingCockpitScreen'));
    expect(cockpit, contains('GoViaCarMapSurface'));
    expect(cockpit, contains('recordingMode = true'));
    expect(cockpit, contains('updateRecordingOverlay'));
    expect(cockpit, contains('Stopp og lagre'));
    expect(cockpit, contains('NavigationTemplate.Builder'));
    expect(cockpit, isNot(contains('PaneTemplate.Builder(pane)')));
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
    expect(pubspec, contains('version: 0.1.37+38'));
  });

  test('cockpit avoids density-scaled giant cards and coordinate leakage', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    expect(overlay, contains('scaleUnit()'));
    expect(overlay, isNot(contains('resources.displayMetrics.density')));
    expect(navigation, contains('cleanTripName(trip.name)'));
    expect(navigation, contains('progressMeters + 15.0'));
  });
}
