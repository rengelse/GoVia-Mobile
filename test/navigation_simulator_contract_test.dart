import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/config/dev_features.dart';
import 'package:govia_mobile/dev/navigation_simulator/navigation_simulator_screen.dart';
import 'package:govia_mobile/dev/navigation_simulator/simulator_controller.dart';
import 'package:govia_mobile/dev/navigation_simulator/simulator_models.dart';

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

  testWidgets('development simulator UI remains buildable', (tester) async {
    expect(const NavigationSimulatorScreen(), isA<NavigationSimulatorScreen>());
  });

  test('simulator is part of ordinary debug app behind one compile-time gate', () {
    final devFeatures = File('lib/core/config/dev_features.dart').readAsStringSync();
    final productionMain = File('lib/main.dart').readAsStringSync();
    final productionApp = File('lib/app/govia_app.dart').readAsStringSync();
    final profile = File('lib/features/profile/presentation/profile_screen.dart').readAsStringSync();
    final workflow = File('.github/workflows/android-release.yml').readAsStringSync();

    expect(devFeatures, contains('static const bool navigationSimulator = kDebugMode'));
    expect(productionMain, isNot(contains('main_dev.dart')));
    expect(productionApp, contains('DevFeatures.navigationSimulator'));
    expect(productionApp, contains('NavigationSimulatorScreen'));
    expect(profile, contains("const SectionTitle('Utviklerverktøy')"));
    expect(profile, contains('DevFeatures.navigationSimulator'));
    expect(profile, contains('AppRoutes.navigationSimulator'));
    expect(workflow, contains('flutter build apk --debug'));
    expect(workflow, isNot(contains('-t lib/main_dev.dart')));
    expect(kReleaseMode, isFalse);
    expect(DevFeatures.navigationSimulator, isTrue);
  });
}
