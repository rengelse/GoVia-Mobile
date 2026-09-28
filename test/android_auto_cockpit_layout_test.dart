import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final carRoot = Directory('android/app/src/main/kotlin/no/govia/mobile/car');

  test('Android Auto uses one session-owned MapLibre surface', () {
    final surface = File('${carRoot.path}/GoViaCarMapSurface.kt').readAsStringSync();
    final runtime = File('${carRoot.path}/GoViaCarRuntime.kt').readAsStringSync();
    expect(surface, contains('MapView'));
    expect(surface, contains('createVirtualDisplay'));
    expect(runtime, contains('setSurfaceCallback(mapSurface)'));
    expect(runtime, contains('setSurfaceCallback(null)'));
    for (final file in carRoot.listSync().whereType<File>()) {
      if (!file.path.endsWith('Screen.kt')) continue;
      final source = file.readAsStringSync();
      expect(source, isNot(contains('setSurfaceCallback(')));
      expect(source, isNot(contains('mapSurface.close()')));
    }
  });

  test('surface is map-only and native templates own visible car UI', () {
    final surface = File('${carRoot.path}/GoViaCarMapSurface.kt').readAsStringSync();
    final navigation = File('${carRoot.path}/GoViaCarNavigationScreen.kt').readAsStringSync();
    expect(surface, contains('Surface contains map tiles only'));
    expect(surface, isNot(contains('GoViaCarCockpitOverlayView')));
    expect(surface, isNot(contains('cockpitOverlay')));
    expect(navigation, contains('NavigationTemplate.Builder'));
    expect(navigation, contains('.setNavigationInfo('));
    expect(navigation, contains('.setDestinationTravelEstimate('));
    expect(navigation, contains('.setMapActionStrip('));
    expect(navigation, isNot(contains('updateNavigationOverlay')));
    expect(navigation, isNot(contains('invisibleRequiredActionStrip')));
  });

  test('active navigation is driven by a foreground navigation service', () {
    final service = File('${carRoot.path}/GoViaNavigationService.kt').readAsStringSync();
    final runtime = File('${carRoot.path}/GoViaCarRuntime.kt').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(service, contains('class GoViaNavigationService : Service()'));
    expect(service, contains('navigationStarted()'));
    expect(service, contains('navigationEnded()'));
    expect(service, contains('manager.updateTrip('));
    expect(service, contains('onAutoDriveEnabled()'));
    expect(service, contains('USAGE_ASSISTANCE_NAVIGATION_GUIDANCE'));
    expect(service, contains('AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK'));
    expect(service, contains('CarAppExtender.Builder()'));
    expect(runtime, contains('bindService('));
    expect(manifest, contains('android:name=".car.GoViaNavigationService"'));
    expect(manifest, contains('android:foregroundServiceType="location"'));
  });

  test('CarAppService and navigation service run in the same car process', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final carService = RegExp(r'android:name="\.car\.GoViaCarAppService"[\s\S]*?android:process=":car"');
    final navService = RegExp(r'android:name="\.car\.GoViaNavigationService"[\s\S]*?android:process=":car"');
    expect(carService.hasMatch(manifest), isTrue);
    expect(navService.hasMatch(manifest), isTrue);
  });


  test('native GoVia home and real app icon are used', () {
    final session = File('${carRoot.path}/GoViaCarSession.kt').readAsStringSync();
    final home = File('${carRoot.path}/GoViaCarHomeScreen.kt').readAsStringSync();
    final surface = File('${carRoot.path}/GoViaCarMapSurface.kt').readAsStringSync();
    expect(session, contains('GoViaCarHomeScreen(carContext, runtime)'));
    expect(home, contains('.setHeaderAction(Action.APP_ICON)'));
    expect(home, contains('"Turer"'));
    expect(home, contains('"Ta opp tur"'));
    expect(home, contains('"Søk destinasjon"'));
    expect(surface, contains('R.mipmap.ic_launcher'));
    expect(surface, isNot(contains('lineTo(16f, 57f)')));
  });

  test('trip browser uses native templates and respects four-tab limit', () {
    final trips = File('${carRoot.path}/GoViaCarTripsScreen.kt').readAsStringSync();
    expect(trips, contains('TabTemplate.Builder'));
    expect(trips, contains('"Planlagt"'));
    expect(trips, contains('"Aktiv"'));
    expect(trips, contains('"Fullført"'));
    expect(trips, contains('"Mer"'));
    expect(RegExp(r'\.addTab\(').allMatches(trips).length, 4);
    expect(trips, contains('"Søk destinasjon"'));
    expect(trips, contains('"Ta opp tur"'));
    expect(trips, isNot(contains('updateTripsOverlay')));
  });

  test('route preview uses MapWithContentTemplate on Car API 7+', () {
    final detail = File('${carRoot.path}/GoViaCarTripDetailScreen.kt').readAsStringSync();
    expect(detail, contains('carContext.carAppApiLevel < 7'));
    expect(detail, contains('MapWithContentTemplate.Builder'));
    expect(detail, contains('PaneTemplate.Builder'));
    expect(detail, contains('MapController.Builder'));
    expect(detail, contains('"Start tur"'));
  });

  test('recording flow uses native templates instead of NavigationTemplate misuse', () {
    final ready = File('${carRoot.path}/GoViaCarRecordScreen.kt').readAsStringSync();
    final recording = File('${carRoot.path}/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    expect(ready, contains('PaneTemplate.Builder'));
    expect(ready, isNot(contains('NavigationTemplate.Builder')));
    expect(recording, contains('MapWithContentTemplate.Builder'));
    expect(recording, contains('MapController.Builder'));
    expect(recording, isNot(contains('NavigationTemplate.Builder')));
    expect(recording, contains('GoViaCarStopRecordingConfirmScreen'));
  });

  test('native destination search reuses route preview and navigation flow', () {
    final search = File('${carRoot.path}/GoViaCarSearchScreen.kt').readAsStringSync();
    expect(search, contains('SearchTemplate.Builder(this)'));
    expect(search, contains('/api/v1/map/geocode'));
    expect(search, contains('/api/v1/map/route'));
    expect(search, contains('GoViaCarTripDetailScreen(carContext, trip, runtime)'));
  });

  test('navigation intents are declared and handled in Session', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final session = File('${carRoot.path}/GoViaCarSession.kt').readAsStringSync();
    expect(manifest, contains('androidx.car.app.action.NAVIGATE'));
    expect(manifest, contains('android:scheme="geo"'));
    expect(session, contains('CarContext.ACTION_NAVIGATE'));
    expect(session, contains('override fun onNewIntent(intent: Intent)'));
  });

  test('phone UI remains detached from Android Auto bridge writes', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    expect(state, contains('void _scheduleAndroidAutoSync()'));
    expect(state, isNot(contains('@override\n  void notifyListeners()')));
    expect(state, contains('if (encoded == _lastAndroidAutoStateJson) return;'));
  });

  test('release version markers stay synchronized', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final release = File('RELEASE.md').readAsStringSync();
    final match = RegExp(r'^version: ([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    final version = match!.group(1)!;
    expect(readme, startsWith('# GoVia Mobile v$version'));
    expect(release, startsWith('# GoVia Mobile v$version'));
  });

  test('GitHub workflow remains packaged for APK builds', () {
    final workflow = File('.github/workflows/android-release.yml').readAsStringSync();
    expect(workflow, contains('flutter build apk --release'));
    expect(workflow, contains('Upload debug APK artifact'));
  });
}
