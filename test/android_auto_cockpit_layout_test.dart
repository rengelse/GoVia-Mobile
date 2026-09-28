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
    expect(navigation, contains('GoViaCarTemplateCompat.invisibleRequiredActionStrip()'));
    final compat = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTemplateCompat.kt').readAsStringSync();
    expect(compat, contains('ActionStrip::class.java.getDeclaredConstructor()'));
    expect(navigation, isNot(contains('.addAction(Action.APP_ICON)')));
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

  test('recording ready screen uses locked GoVia surface UI and REC cockpit', () {
    final record = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final cockpit = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    expect(record, contains('GoViaCarMapSurface'));
    expect(record, contains('updateRecordReadyOverlay'));
    expect(record, contains('GoViaCarTemplateCompat.invisibleRequiredActionStrip()'));
    expect(record, contains('GoViaCarRecordingCockpitScreen'));
    expect(record, isNot(contains('PaneTemplate')));
    expect(overlay, contains('Mode.RECORD_READY -> drawRecordReady(canvas)'));
    expect(overlay, contains('Klar til opptak'));
    expect(overlay, contains('GPS klar'));
    expect(overlay, contains('Start opptak'));
    expect(cockpit, contains('GoViaCarMapSurface'));
    expect(cockpit, contains('recordingMode = true'));
    expect(cockpit, contains('updateRecordingOverlay'));
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

  test('release version markers stay synchronized', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final release = File('RELEASE.md').readAsStringSync();
    final match = RegExp(r'^version: ([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)$', multiLine: true).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml must contain a semantic build version');
    final version = match!.group(1)!;
    expect(readme, contains('# GoVia Mobile v$version'));
    expect(release, startsWith('# GoVia Mobile v$version'));
  });

  test('cockpit avoids density-scaled giant cards and coordinate leakage', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    expect(overlay, contains('unit()'));
    expect(overlay, isNot(contains('resources.displayMetrics.density')));
    expect(navigation, contains('cleanTripName(trip.name)'));
    expect(navigation, contains('progressMeters + 15.0'));
  });


  test('Android Auto opens directly on the trips overview', () {
    final session = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarSession.kt').readAsStringSync();
    expect(session, contains('GoViaCarTripsScreen(carContext)'));
    expect(session, isNot(contains('GoViaCarHomeScreen(carContext)')));
  });

  test('trips use locked Planlagt Aktiv Fullført Ta opp controls and route cards', () {
    final trips = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripsScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    expect(trips, contains('updateTripsOverlay'));
    expect(trips, contains('NavigationTemplate.Builder'));
    expect(trips, isNot(contains('TabTemplate.Builder')));
    expect(overlay, contains('TAB_PLANNED'));
    expect(overlay, contains('TAB_ACTIVE'));
    expect(overlay, contains('TAB_COMPLETED'));
    expect(overlay, contains('TAB_RECORD'));
    expect(overlay, contains('"Ta opp"'));
    expect(trips, contains('GoViaCarRecordScreen(carContext)'));
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

  test('overview templates keep required but invisible host action strips', () {
    final home = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarHomeScreen.kt').readAsStringSync();
    final trips = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripsScreen.kt').readAsStringSync();
    expect(home, contains('GoViaCarTemplateCompat.invisibleRequiredActionStrip()'));
    expect(home, contains('.setActionStrip(requiredActionStrip)'));
    expect(trips, contains('GoViaCarTemplateCompat.invisibleRequiredActionStrip()'));
    expect(trips, contains('.setActionStrip(requiredActionStrip)'));
    expect(home, isNot(contains('Action.APP_ICON')));
    expect(trips, isNot(contains('Action.APP_ICON')));
  });


  test('all GoVia-owned Android Auto headers use the official logo asset', () {
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    expect(overlay, contains('R.drawable.govia_logo_horizontal'));
    expect(overlay, contains('drawBrandHeader(canvas, u, t, null, back = false)'));
    expect(overlay, isNot(contains('Compact GoVia route mark')));
    expect(File('android/app/src/main/res/drawable/govia_logo_horizontal.png').existsSync(), isTrue);
  });

  test('stop control is separated and requires confirmation', () {
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final confirm = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarEndTripConfirmScreen.kt').readAsStringSync();
    expect(navigation, contains('onStop = { requestStopConfirmation() }'));
    expect(navigation, contains('GoViaCarEndTripConfirmScreen(carContext)'));
    expect(overlay, contains('val gap = 18f * u'));
    expect(overlay, contains('val stopBottom = height - 24f * u'));
    expect(confirm, contains('Vil du avslutte den aktive turen?'));
    expect(confirm, contains('Fortsett tur'));
    expect(confirm, contains('Avslutt tur'));
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

  test('recording cockpit shares GoVia navigation controls and confirms stop', () {
    final recording = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    final overlay = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarCockpitOverlayView.kt').readAsStringSync();
    final confirm = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarStopRecordingConfirmScreen.kt').readAsStringSync();

    expect(recording, contains('invisibleRequiredActionStrip'));
    expect(recording, isNot(contains('setMapActionStrip')));
    expect(recording, contains('onZoomIn'));
    expect(recording, contains('onZoomOut'));
    expect(recording, contains('onRecenter'));
    expect(recording, contains('requestStopRecordingConfirmation'));
    expect(overlay, contains('drawRecordingControls'));
    expect(confirm, contains('Fortsett opptak'));
    expect(confirm, contains('Stopp og lagre'));
  });

}
