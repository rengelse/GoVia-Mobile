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
    expect(navigation, contains('.setActionStrip(requiredActionStrip)'));
    expect(navigation, isNot(contains('.setMapActionStrip(')));
    expect(navigation, isNot(contains('.setTitle("Avslutt")')));
    expect(navigation, isNot(contains('R.drawable.ic_car_sound')));
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
    expect(pubspec, matches(RegExp(r'version: 0\.1\.49\+50\b')));
  });

  test('cockpit avoids density-scaled giant cards and coordinate leakage', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    expect(overlay, contains('unit()'));
    expect(overlay, isNot(contains('resources.displayMetrics.density')));
    expect(navigation, contains('cleanTripName(trip.name)'));
    expect(navigation, contains('progressMeters + 15.0'));
  });


  test('home uses locked GoVia surface cards instead of host grid tiles', () {
    final home = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarHomeScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    expect(home, contains('updateHomeOverlay'));
    expect(home, contains('NavigationTemplate.Builder'));
    expect(home, isNot(contains('GridTemplate.Builder')));
    expect(home, isNot(contains('GridItem.Builder')));
    expect(overlay, contains('drawHomeCard'));
    expect(overlay, contains('HOME_TRIPS'));
    expect(overlay, contains('HOME_RECORD'));
    expect(overlay, contains('Fortsett tur'));
  });

  test('trips use locked Planlagt Aktiv Fullført surface tabs and route cards', () {
    final trips = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripsScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    expect(trips, contains('updateTripsOverlay'));
    expect(trips, contains('NavigationTemplate.Builder'));
    expect(trips, isNot(contains('TabTemplate.Builder')));
    expect(overlay, contains('TAB_PLANNED'));
    expect(overlay, contains('TAB_ACTIVE'));
    expect(overlay, contains('TAB_COMPLETED'));
    expect(overlay, contains('TripCard'));
    expect(overlay, contains('drawRouteCardIcon'));
  });

  test('active cockpit includes dedicated lower arrival and remaining status pill', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    // Verify the actual status-pill structure, not a comment string.
    expect(overlay, contains('val statusRect = RectF'));
    expect(overlay, contains('roundPanel(canvas, statusRect'));
    expect(overlay, contains('navigationState.arrival.removePrefix("Ankomst ")'));
    expect(overlay, contains('navigationState.remaining.removeSuffix(" igjen")'));
    expect(overlay, contains('canvas.drawText("Ankomst"'));
    expect(overlay, contains('canvas.drawText("igjen"'));
  });

  test('ending navigation or recording always returns to GoVia root', () {
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    final recording = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    expect(navigation, contains('screenManager.popToRoot()'));
    expect(recording, contains('screenManager.popToRoot()'));
    expect(navigation, isNot(contains('screenManager.pop()')));
    expect(recording, isNot(contains('screenManager.pop()')));
  });


  test('navigation cockpit matches locked visual structure', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final surface = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarMapSurface.kt').readAsStringSync();
    expect(overlay, contains('drawHeader(canvas, u, t)'));
    expect(overlay, contains('POI nærmer seg'));
    expect(overlay, contains('drawNavigationControls'));
    expect(overlay, contains('Control.SOUND'));
    expect(overlay, contains('Control.STOP'));
    expect(surface, contains('override fun onClick(x: Float, y: Float)'));
    expect(surface, contains('mapView.height * 0.42f'));
    expect(surface, contains('.width(5.5f)'));
  });

  test('home and trips hide host floating actions on modern Car API hosts', () {
    final home = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarHomeScreen.kt').readAsStringSync();
    final trips = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripsScreen.kt').readAsStringSync();

    // Car API 7+ must use a surface-only MapWithContentTemplate without
    // ActionStrip, so Android Auto does not draw duplicate floating buttons.
    expect(home, contains('carAppApiLevel >= 7'));
    expect(home, contains('MapWithContentTemplate.Builder()'));
    expect(trips, contains('carAppApiLevel >= 7'));
    expect(trips, contains('MapWithContentTemplate.Builder()'));

    final homeModern = home.substring(home.indexOf('if (carContext.carAppApiLevel >= 7)'), home.indexOf('// Compatibility fallback'));
    final tripsModern = trips.substring(trips.indexOf('if (carContext.carAppApiLevel >= 7)'), trips.indexOf('// Compatibility fallback'));
    expect(homeModern, isNot(contains('setActionStrip')));
    expect(homeModern, isNot(contains('Action.APP_ICON')));
    expect(tripsModern, isNot(contains('setActionStrip')));
    expect(tripsModern, isNot(contains('Action.BACK')));

    // Older hosts keep the safe NavigationTemplate fallback.
    expect(home, contains('.addAction(Action.APP_ICON)'));
    expect(trips, contains('.addAction(Action.BACK)'));
  });

  test('guidance card contains only next maneuver content', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final start = overlay.indexOf('private fun drawNavigation(canvas: Canvas)');
    final poi = overlay.indexOf('// POI card:', start);
    final guidance = overlay.substring(start, poi);
    expect(guidance, contains('navigationState.distance'));
    expect(guidance, contains('navigationState.instruction'));
    expect(guidance, contains('navigationState.road'));
    expect(guidance, isNot(contains('navigationState.tripName')));
    expect(guidance, isNot(contains('navigationState.remaining')));
    expect(guidance, isNot(contains('navigationState.arrival')));
    expect(guidance, isNot(contains('drawRouteMiniIcon')));
  });

  test('phone UI and Android Auto run in isolated processes with file bridge', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final mainActivity = File('android/app/src/main/kotlin/no/govia/mobile/MainActivity.kt').readAsStringSync();
    final repository = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRepository.kt').readAsStringSync();
    final bridge = File('android/app/src/main/kotlin/no/govia/mobile/CarBridgeStore.kt').readAsStringSync();

    expect(manifest, contains('android:name=".car.GoViaCarAppService"'));
    expect(manifest, contains('android:process=":car"'));
    expect(mainActivity, contains('CarBridgeStore(this).writeState(json)'));
    expect(mainActivity, contains('CarBridgeStore(this).drainRecordedRides()'));
    expect(repository, contains('CarBridgeStore(context.applicationContext)'));
    expect(bridge, contains('AtomicFile'));
    expect(bridge, contains('RandomAccessFile'));
  });

}
