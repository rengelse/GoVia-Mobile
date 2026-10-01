import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/govia_theme.dart';
import '../../features/navigation/presentation/navigation_screen.dart';
import '../../domain/models.dart';
import '../../domain/transport_profiles.dart';
import 'simulator_controller.dart';
import 'simulator_models.dart';

class NavigationSimulatorScreen extends StatefulWidget {
  const NavigationSimulatorScreen({super.key});

  @override
  State<NavigationSimulatorScreen> createState() => _NavigationSimulatorScreenState();
}

class _NavigationSimulatorScreenState extends State<NavigationSimulatorScreen> {
  final scenarios = buildNavigationSimulatorScenarios();
  final Set<String> _resolvingScenarioIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoViaColors.bg,
      appBar: AppBar(
        title: const Text('GoVia Navigation Simulator'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(child: _DevBadge()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          const Text(
            'Utviklingsverktøy – følger ikke produksjonsbygget',
            style: TextStyle(color: GoViaColors.orange, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Simulatoren bygger først ruten gjennom GoVia sitt ordinære routing-API, slik at GPS-sporet følger veinettet og bruker reelle manøvrer. '
            'Samme rute kan synkes til Android Auto for DHU/AutoDrive-testing.',
            style: TextStyle(color: GoViaColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (final scenario in scenarios) ...[
            _ScenarioCard(
              scenario: scenario,
              busy: _resolvingScenarioIds.contains(scenario.id),
              onRun: () => _runScenario(scenario),
              onSendToCar: () => _sendToAndroidAuto(scenario),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<NavigationSimulatorScenario?> _resolveRoadNetworkScenario(NavigationSimulatorScenario scenario) async {
    if (_resolvingScenarioIds.contains(scenario.id)) return null;
    setState(() => _resolvingScenarioIds.add(scenario.id));
    try {
      final state = AppScope.of(context);
      final payload = {
        'points': [
          for (final point in scenario.routePoints) {'coord': point.coord, 'name': point.name},
        ],
        'mode': routeModeForTransport(scenario.stage.transport),
        'profile': scenario.stage.routeProfile,
        'preferences': scenario.stage.routePreferences.toJson(),
      };
      late Map<String, dynamic> response;
      try {
        response = await state.api.postJson('/api/v1/map/route', payload);
      } catch (_) {
        response = await state.api.postJson('/api/v1/map/route', {
          'points': payload['points'],
          'mode': payload['mode'],
        });
      }
      final route = parseNavigationSimulatorRoadRoute(response, scenario: scenario);
      if (scenario.id == 'urban' && !hasRoundaboutSemantic(route.maneuvers) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rundkjøringsdiagnostikk: verken route- eller guidance-kilden leverte roundabout-semantikk. Dette er et routing/provider-gap.'),
          ),
        );
      }
      if (route.geometry.length < 8) {
        throw StateError('Rutekilden returnerte for grov geometri til simulatoren (${route.geometry.length} punkter).');
      }
      return scenario.withRoadNetworkStage(buildNavigationSimulatorRoadStage(scenario, route));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunne ikke bygge veinett-rute for ${scenario.name}: $error')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _resolvingScenarioIds.remove(scenario.id));
    }
  }

  Future<void> _runScenario(NavigationSimulatorScenario scenario) async {
    final resolved = await _resolveRoadNetworkScenario(scenario);
    if (resolved == null || !mounted) return;
    final controller = NavigationSimulatorController(resolved);
    controller.start();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          stage: resolved.stage,
          locationStream: controller.stream,
          developerOverlay: _SimulatorOverlay(controller: controller),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _sendToAndroidAuto(NavigationSimulatorScenario scenario) async {
    final resolved = await _resolveRoadNetworkScenario(scenario);
    if (resolved == null || !mounted) return;
    final state = AppScope.of(context);
    await state.addLocalTrip(resolved.trip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${resolved.name} er synket som aktiv DEV-tur til Android Auto. Start den i DHU og bruk AutoDrive.'),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario, required this.busy, required this.onRun, required this.onSendToCar});

  final NavigationSimulatorScenario scenario;
  final bool busy;
  final VoidCallback onRun;
  final VoidCallback onSendToCar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_rounded, color: GoViaColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(scenario.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ),
                if (scenario.autoStress) const _DevBadge(text: 'AUTO STRESS'),
              ],
            ),
            const SizedBox(height: 8),
            Text(scenario.description, style: const TextStyle(color: GoViaColors.muted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const _Metric('Veinett-rute'),
                _Metric('${scenario.routePoints.length} rutepunkter'),
                _Metric(scenario.stage.routeProfile),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onRun,
                    icon: busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(busy ? 'Bygger rute…' : 'Kjør simulator'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onSendToCar,
                    icon: const Icon(Icons.directions_car_outlined),
                    label: const Text('Til Android Auto'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: GoViaColors.panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: GoViaColors.border),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _SimulatorOverlay extends StatefulWidget {
  const _SimulatorOverlay({required this.controller});
  final NavigationSimulatorController controller;

  @override
  State<_SimulatorOverlay> createState() => _SimulatorOverlayState();
}

class _SimulatorOverlayState extends State<_SimulatorOverlay> {
  bool _expanded = true;

  NavigationSimulatorController get controller => widget.controller;

  void _refresh(VoidCallback action) {
    action();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: const Color(0xF21B1F25),
            borderRadius: BorderRadius.circular(16),
            elevation: 12,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 160),
              child: _expanded ? _expandedPanel() : _collapsedPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsedPanel() => IconButton(
        tooltip: 'Åpne simulator',
        onPressed: () => setState(() => _expanded = true),
        icon: const Icon(Icons.science_rounded, color: GoViaColors.orange),
      );

  Widget _expandedPanel() => SizedBox(
        width: 178,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: _DevBadge(text: 'SIMULATOR')),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _expanded = false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _refresh(controller.running ? controller.pause : controller.resume),
                      icon: Icon(controller.running ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(controller.running ? 'Pause' : 'Kjør'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final speed in const [1.0, 2.0, 5.0, 10.0])
                    ChoiceChip(
                      label: Text('${speed.toInt()}×'),
                      selected: controller.speedMultiplier == speed,
                      onSelected: (_) => _refresh(() => controller.setSpeedMultiplier(speed)),
                    ),
                ],
              ),
              const Divider(height: 16),
              _Control('Neste manøver', Icons.skip_next_rounded, controller.jumpToNextManeuver, _refresh),
              _Control('Off-route', Icons.alt_route_rounded, controller.injectOffRoute, _refresh),
              _Control('GPS-jitter', Icons.gps_not_fixed_rounded, controller.injectGpsJitter, _refresh),
              _Control('GPS-tap', Icons.gps_off_rounded, () => controller.injectGpsLoss(), _refresh),
              _Control('Stopp 8 sek', Icons.timer_off_outlined, () => controller.injectStop(), _refresh),
              _Control('Ankomst', Icons.flag_rounded, controller.jumpToArrival, _refresh),
            ],
          ),
        ),
      );
}

class _Control extends StatelessWidget {
  const _Control(this.label, this.icon, this.action, this.refresh);
  final String label;
  final IconData icon;
  final VoidCallback action;
  final void Function(VoidCallback) refresh;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(alignment: Alignment.centerLeft, visualDensity: VisualDensity.compact),
          onPressed: () => refresh(action),
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

class _DevBadge extends StatelessWidget {
  const _DevBadge({this.text = 'DEV ONLY'});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GoViaColors.orange.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: GoViaColors.orange.withValues(alpha: .65)),
        ),
        child: Text(text, style: const TextStyle(color: GoViaColors.orange, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}
