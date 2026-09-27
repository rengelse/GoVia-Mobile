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

  test('active navigation uses full-map GoVia overlay without host routing card', () {
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();

    // Contract: GoVia owns guidance presentation on the map surface; Android Auto
    // supplies the safe action strips only. Do not pin this test to display copy.
    expect(navigation, contains('mapSurface.updateNavigationOverlay('));
    expect(navigation, contains('NavigationTemplate.Builder'));
    expect(navigation, contains('.setActionStrip(mainActions)'));
    expect(navigation, contains('.setMapActionStrip(mapActions)'));
    expect(navigation, isNot(contains('.setNavigationInfo(')));

    // Contract: the overlay supports navigation, POI and recording modes.
    expect(overlay, contains('Mode.PREVIEW -> drawPreview(canvas)'));
    expect(overlay, contains('Mode.NAVIGATION -> drawNavigation(canvas)'));
    expect(overlay, contains('Mode.RECORDING -> drawRecording(canvas)'));
    expect(overlay, contains('navigationState.poi'));
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

  test('trip detail uses compact map-first preview overlay', () {
    final detail = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripDetailScreen.kt').readAsStringSync();
    expect(detail, contains('GoViaCarMapSurface'));
    expect(detail, contains('updatePreviewOverlay'));
    expect(detail, contains('NavigationTemplate.Builder'));
    expect(detail, contains('Start tur'));
    expect(detail, isNot(contains('PaneTemplate')));
    expect(detail, isNot(contains('MapWithContentTemplate')));
  });

  test('main branch CI exposes downloadable debug APK', () {
    final workflow = File('.github/workflows/android-release.yml').readAsStringSync();
    expect(workflow, contains('Upload debug APK artifact'));
    expect(workflow, contains('build/app/outputs/flutter-apk/app-debug.apk'));
  });

  test('Android Auto version marker bumped', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, matches(RegExp(r'version: 0\.1\.41\+42\b')));
  });

  test('cockpit avoids density-scaled giant cards and coordinate leakage', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    expect(overlay, contains('scaleUnit()'));
    expect(overlay, isNot(contains('resources.displayMetrics.density')));
    expect(navigation, contains('cleanTripName(trip.name)'));
    expect(navigation, contains('progressMeters + 15.0'));
  });


  test('home uses large Android Auto grid cards instead of a plain text list', () {
    final home = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarHomeScreen.kt').readAsStringSync();
    expect(home, contains('GridTemplate.Builder'));
    expect(home, contains('GridItem.Builder'));
    expect(home, contains('Turer'));
    expect(home, contains('Ta opp'));
    expect(home, isNot(contains('ListTemplate.Builder')));
  });

  test('trips use Planlagt Aktiv Fullført tabs on supported car hosts', () {
    final trips = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripsScreen.kt').readAsStringSync();
    expect(trips, contains('TabTemplate.Builder'));
    expect(trips, contains('Planlagt'));
    expect(trips, contains('Aktiv'));
    expect(trips, contains('Fullført'));
    expect(trips, contains('carAppApiLevel < 6'));
  });

  test('active cockpit includes dedicated lower arrival and remaining status pill', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    expect(overlay, contains('Dedicated lower status pill'));
    expect(overlay, contains('Ankomst'));
    expect(overlay, contains('igjen'));
  });

  test('ending navigation or recording always returns to GoVia root', () {
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    final recording = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    expect(navigation, contains('screenManager.popToRoot()'));
    expect(recording, contains('screenManager.popToRoot()'));
    expect(navigation, isNot(contains('screenManager.pop()')));
    expect(recording, isNot(contains('screenManager.pop()')));
  });

}
