import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/dev/navigation_simulator/navigation_simulator_screen.dart';
import 'package:govia_mobile/dev/navigation_simulator/simulator_controller.dart';
import 'package:govia_mobile/dev/navigation_simulator/simulator_models.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('development simulator ships multiple navigation scenarios', () {
    final scenarios = buildNavigationSimulatorScenarios();
    expect(scenarios.length, greaterThanOrEqualTo(3));
    expect(scenarios.any((scenario) => scenario.autoStress), isTrue);
    expect(scenarios.every((scenario) => scenario.stage.routeCandidates.first.geometry.length >= 2), isTrue);
    expect(scenarios.every((scenario) => scenario.stage.routeCandidates.first.maneuvers.isNotEmpty), isTrue);

    final controller = NavigationSimulatorController(scenarios.first);
    expect(controller.route.geometry, isNotEmpty);
    controller.dispose();
  });


  test('simulator semantic scoring prefers roundabout-rich guidance over generic turns', () {
    final generic = <NavigationManeuver>[
      NavigationManeuver(
        id: 'g1', sequence: 0, type: 'turn', modifier: 'right', instruction: 'Ta til høyre',
        location: const GeoPoint(lat: 60.47, lon: 5.33), source: 'provider', confidence: 1,
      ),
    ];
    final rich = <NavigationManeuver>[
      NavigationManeuver(
        id: 'r1', sequence: 0, type: 'roundabout', modifier: 'right', instruction: 'Rundkjøring',
        location: const GeoPoint(lat: 60.47, lon: 5.33), exit: 2, source: 'geometry', confidence: .8,
      ),
    ];
    expect(navigationSemanticScore(rich), greaterThan(navigationSemanticScore(generic)));
    expect(hasRoundaboutSemantic(rich), isTrue);
    expect(hasRoundaboutSemantic(generic), isFalse);
  });

  testWidgets('development simulator UI remains buildable', (tester) async {
    expect(const NavigationSimulatorScreen(), isA<NavigationSimulatorScreen>());
  });

  test('single GitHub APK enables simulator through removable compile-time define', () {
    final devFeatures = File('lib/core/config/dev_features.dart').readAsStringSync();
    final productionApp = File('lib/app/govia_app.dart').readAsStringSync();
    final profile = File('lib/features/profile/presentation/profile_screen.dart').readAsStringSync();
    final workflow = File('.github/workflows/android-release.yml').readAsStringSync();

    expect(devFeatures, contains("'GOVIA_NAV_SIMULATOR'"));
    expect(devFeatures, contains('bool.fromEnvironment'));
    expect(devFeatures, contains('defaultValue: false'));
    expect(productionApp, contains('DevFeatures.navigationSimulator'));
    expect(productionApp, contains('NavigationSimulatorScreen'));
    expect(profile, contains("const SectionTitle('Utviklerverktøy')"));
    expect(profile, contains('DevFeatures.navigationSimulator'));
    expect(profile, contains('AppRoutes.navigationSimulator'));
    expect(workflow, contains('--dart-define=GOVIA_NAV_SIMULATOR=true'));
    expect(workflow, contains('flutter build apk --release'));
    expect(workflow, isNot(contains('-t lib/main_dev.dart')));
  });

  test('simulator parses dense road-network route and provider maneuvers', () {
    final scenario = buildNavigationSimulatorScenarios().first;
    final geometry = <List<double>>[
      [5.3221, 60.3913],
      [5.3224, 60.3915],
      [5.3228, 60.3918],
      [5.3232, 60.3920],
      [5.3237, 60.3923],
      [5.3242, 60.3927],
      [5.3248, 60.3930],
      [5.3254, 60.3934],
      [5.3260, 60.3938],
    ];
    final route = parseNavigationSimulatorRoadRoute({
      'data': {
        'distance': 1250,
        'duration': 110,
        'geometry': geometry,
        'guidanceSource': 'provider-native',
        'maneuvers': [
          {
            'id': 'm0',
            'sequence': 0,
            'type': 'roundabout',
            'modifier': 'right',
            'instruction': 'Ta andre avkjøring',
            'location': [5.3242, 60.3927],
            'distanceFromStartMeters': 600,
            'exit': 2,
          }
        ],
      }
    }, scenario: scenario);
  
    expect(route.geometry.length, 9);
    expect(route.maneuvers.single.type, 'roundabout');
    expect(route.maneuvers.single.exit, 2);
    expect(route.guidanceSource, 'provider-native');
  });
}
