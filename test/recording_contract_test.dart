import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone recording uses persistent native foreground recorder', () {
    final screen = File('lib/features/new_trip/presentation/record_ride_screen.dart').readAsStringSync();
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final activity = File('android/app/src/main/kotlin/no/govia/mobile/MainActivity.kt').readAsStringSync();
    final service = File('android/app/src/main/kotlin/no/govia/mobile/car/CarRideRecordingService.kt').readAsStringSync();
    final bridge = File('android/app/src/main/kotlin/no/govia/mobile/CarBridgeStore.kt').readAsStringSync();
    final repo = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRepository.kt').readAsStringSync();

    expect(screen, contains('startRideRecording()'));
    expect(screen, contains('stopRideRecordingAndImport()'));
    expect(screen, isNot(contains('final points=<Position>[]')));
    expect(state, contains("invokeMethod<bool>('startRideRecording')"));
    expect(state, contains("invokeMethod<bool>('stopRideRecording')"));
    expect(state, contains('_importAndroidAutoRecordings()'));
    expect(activity, contains('CarRideRecordingService.ACTION_START'));
    expect(activity, contains('CarRideRecordingService.ACTION_STOP'));
    expect(service, contains('appendRecordedRide'));
    expect(bridge, contains('recording_state.json'));
    expect(bridge, contains('fun isRecording(): Boolean'));
    expect(repo, contains('bridge.setRecording(active)'));
    expect(repo, contains('bridge.isRecording()'));
    expect(state, contains('for (var attempt = 0; attempt < 25; attempt++)'));
    expect(state, contains('final imported = await _importAndroidAutoRecordings()'));
  });
}
