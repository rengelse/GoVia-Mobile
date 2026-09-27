import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Auto recording enters a cockpit screen instead of staying on a static pane', () {
    final record = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordScreen.kt').readAsStringSync();
    final recordingCockpit = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').readAsStringSync();
    expect(record, contains('GoViaCarRecordingCockpitScreen'));
    expect(record, contains('Når opptaket starter går GoVia rett til cockpitvisning'));
    expect(recordingCockpit, contains('recording = true'));
    expect(recordingCockpit, contains('Stopp og lagre'));
    expect(recordingCockpit, contains('NavigationTemplate.Builder'));
  });

  test('Android Auto navigation surface renders locked cockpit elements', () {
    final renderer = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaRouteSurfaceRenderer.kt').readAsStringSync();
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    expect(renderer, contains('POI nærmer seg'));
    expect(renderer, contains('drawControls'));
    expect(renderer, contains('drawBottomStatus'));
    expect(renderer, contains('drawRecordingFooter'));
    expect(navigation, contains('remainingInfoLine'));
    expect(navigation, contains('estimatedArrivalText'));
    expect(navigation, contains('renderer.updateUiState(buildSurfaceState())'));
  });

  test('Android Auto version marker bumped for cockpit baseline', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 0.1.29+30'));
  });
}
