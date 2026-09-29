import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_route.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_session.dart';

void main() {
  const geometry = [
    GeoPoint(lat: 60.0, lon: 5.0),
    GeoPoint(lat: 60.005, lon: 5.0),
    GeoPoint(lat: 60.01, lon: 5.0),
  ];
  const candidate = RouteCandidate(
    id: 'golden-route',
    name: 'Golden',
    distanceMeters: 1112,
    durationSeconds: 100,
    geometry: geometry,
    maneuvers: [
      NavigationManeuver(
        id: 'm1',
        sequence: 0,
        type: 'continue',
        instruction: 'Fortsett',
        location: GeoPoint(lat: 60.005, lon: 5.0),
        distanceFromStartMeters: 556,
      ),
    ],
  );
  const stage = Stage(
    id: 'golden-stage',
    day: 1,
    order: 0,
    start: 'A',
    end: 'B',
    transport: StageTransport.car,
    routeCandidates: [candidate],
    officialRouteId: 'golden-route',
  );

  Map<String, List<List<String>>> loadTraces() {
    final lines = File('test/fixtures/navigation_core_v2_golden.csv').readAsLinesSync().skip(1);
    final traces = <String, List<List<String>>>{};
    for (final line in lines) {
      final row = line.split(',');
      traces.putIfAbsent(row[0], () => <List<String>>[]).add(row);
    }
    return traces;
  }

  NavigationSessionState runTrace(String name) {
    final session = NavigationSession(NavigationRoute.fromStage(stage, candidate));
    NavigationSessionState? state;
    for (final row in loadTraces()[name]!) {
      state = session.update(NavigationFix(
        lat: double.parse(row[2]),
        lon: double.parse(row[3]),
        speedMetersPerSecond: double.parse(row[4]),
        headingDegrees: double.parse(row[5]),
        accuracyMeters: double.parse(row[6]),
        timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(row[7]), isUtc: true),
      ));
    }
    return state!;
  }

  test('shared golden normal trace advances', () {
    expect(runTrace('normal').progressMeters, greaterThan(700));
  });

  test('shared golden poor-first trace recovers', () {
    expect(runTrace('poor_first_recovery').progressMeters, greaterThan(500));
  });

  test('shared golden out-of-order trace rejects older fix', () {
    final state = runTrace('out_of_order_after_poor');
    expect(state.progressMeters, inInclusiveRange(210, 235));
    expect(state.currentFix?.timestamp.millisecondsSinceEpoch, 3000);
  });

  test('shared golden teleport trace cannot arrive', () {
    final state = runTrace('teleport_guard');
    expect(state.arrived, isFalse);
    expect(state.progressMeters, inInclusiveRange(100, 125));
  });

  test('shared golden arrival trace reaches terminal arrival', () {
    expect(runTrace('arrival').arrived, isTrue);
  });
}
