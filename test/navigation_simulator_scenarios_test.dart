import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/dev/navigation_simulator/simulator_models.dart';

void main() {
  test('simulator exposes the acceptance scenario set', () {
    final scenarios = buildNavigationSimulatorScenarios();
    expect(scenarios.map((s) => s.id).toSet(), containsAll({
      'country-road',
      'motorway-exit',
      'roundabout',
      'intersection',
      'speed-limits',
      'reroute',
      'arrival',
    }));
    expect(scenarios.every((s) => s.routePoints.length >= 3), isTrue);
  });

  test('reroute scenario is the only automatic stress scenario', () {
    final scenarios = buildNavigationSimulatorScenarios();
    expect(scenarios.where((s) => s.autoStress).map((s) => s.id).toList(), ['reroute']);
  });
}
