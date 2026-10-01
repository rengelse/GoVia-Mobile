import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/native_navigation_state.dart';

void main() {
  test('maneuver shapeIndex survives provider model roundtrip', () {
    final maneuver = NavigationManeuver.fromJson({
      'id': 'exit-7',
      'sequence': 2,
      'type': 'off_ramp',
      'modifier': 'right',
      'instruction': 'Ta avkjøring 7',
      'location': [10.0, 60.0],
      'shapeIndex': 12,
      'exit': 7,
      'source': 'tomtom',
      'confidence': 1.0,
    });
    expect(maneuver.shapeIndex, 12);
    expect(maneuver.toJson()['shapeIndex'], 12);
  });

  test('native Ferrostar state is parsed without recomputing navigation', () {
    final state = NativeNavigationState.fromMap({
      'stageId': 'stage-1',
      'routeId': 'route-1',
      'navigating': true,
      'arrived': false,
      'progressMeters': 1250.0,
      'remainingMeters': 3750.0,
      'remainingSeconds': 240,
      'distanceToManeuverMeters': 180.0,
      'snappedPosition': [10.1, 60.1],
      'currentManeuver': {
        'id': 'exit-7', 'sequence': 0, 'type': 'off_ramp', 'modifier': 'right',
        'instruction': 'Ta avkjøring 7', 'exit': 7, 'source': 'ferrostar', 'confidence': 1.0,
      },
      'speedLimitKph': 80,
      'deviation': 'NoDeviation',
      'rerouteRequired': false,
      'spokenInstructionId': 'cue-1',
      'spokenInstructionText': 'Ta avkjøring 7',
      'gpsQuality': 'good',
    });
    expect(state.progressMeters, 1250);
    expect(state.speedLimitKph, 80);
    expect(state.currentManeuver?.type, 'off_ramp');
    expect(state.currentManeuver?.exit, 7);
    expect(state.snappedPosition?.lat, 60.1);
  });
}
