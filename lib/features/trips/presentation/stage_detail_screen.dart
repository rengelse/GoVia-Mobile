import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';
import '../../discover/presentation/publish_route_screen.dart';

class StageDetailScreen extends StatelessWidget {
  const StageDetailScreen({super.key, this.stage});
  final Stage? stage;

  @override
  Widget build(BuildContext context) {
    final stages = AppScope.of(context).activeTrip?.stages ?? const <Stage>[];
    final s = stage ?? (stages.isEmpty ? null : stages.first);
    if (s == null) return const GoViaScreen(title: 'Etappe', child: Text('Ingen etappe valgt.'));
    final ferry = s.transport == StageTransport.ferry;
    final rail = s.transport == StageTransport.train;
    final navigable = !ferry && !rail;
    RouteCandidate? official;
    for (final candidate in s.routeCandidates) {
      if (candidate.id == s.officialRouteId || (official == null && candidate.official)) official = candidate;
    }
    final status = switch (s.status) {
      StageStatus.active => 'Aktiv',
      StageStatus.completed => 'Fullført',
      StageStatus.planned => 'Ikke startet',
    };
    return GoViaScreen(
      title: s.name.trim().isEmpty ? 'Etappe ${s.order + 1}' : s.name,
      subtitle: '${s.start} → ${s.end}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RouteMapCard(height: 260, points: official?.geometry ?? const [], waypoints: s.waypoints, label: ferry ? 'Ferge' : rail ? 'Tog' : 'Offisiell rute'),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          StatusPill(transportLabel(s.transport), color: ferry || rail ? GoViaColors.blue : GoViaColors.orange, icon: ferry ? Icons.directions_boat_filled_outlined : rail ? Icons.train_outlined : Icons.route),
          StatusPill(status, color: s.status == StageStatus.completed ? GoViaColors.green : GoViaColors.orange, icon: s.status == StageStatus.completed ? Icons.check_circle_outline : Icons.schedule_outlined),
          if (s.officialRouteId != null) const StatusPill('Offisiell rute', color: GoViaColors.green, icon: Icons.check_circle_outline),
        ]),
        const SizedBox(height: 18),
        Text('${s.start} → ${s.end}', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Row(children: [
          MetricCard(label: 'Distanse', value: '${(s.distanceMeters / 1000).round()} km', icon: Icons.straighten, color: GoViaColors.orange),
          const SizedBox(width: 10),
          MetricCard(label: 'Tid', value: _duration(s.durationSeconds), icon: Icons.schedule),
        ]),
        if (s.waypoints.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionTitle('Stopp og POI'),
          for (final item in s.waypoints)
            Card(
              child: ListTile(
                leading: Icon(_waypointIcon(item.kind), color: GoViaColors.orange),
                title: Text(item.name),
                subtitle: Text([if (item.category.isNotEmpty) item.category, _kindLabel(item.kind), if (item.note.isNotEmpty) item.note].join(' · ')),
              ),
            ),
        ],
        const SizedBox(height: 18),
        if (navigable)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await AppScope.of(context).startNavigationStage(s);
                if (context.mounted) Navigator.pushNamed(context, AppRoutes.navigation, arguments: s);
              },
              icon: const Icon(Icons.navigation_rounded),
              label: Text(s.status == StageStatus.completed ? 'Kjør etappen igjen' : 'Start denne etappen'),
            ),
          ),
        if (!navigable)
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(ferry ? Icons.directions_boat : Icons.train, color: GoViaColors.blue), const SizedBox(width: 12), Expanded(child: Text(ferry ? 'Ferge håndteres som transportsegment og skal ikke beregnes som veirute.' : 'Tog håndteres som transportsegment og startes ikke som veibasert navigasjon.'))]))),
        if (navigable) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.routeOverview, arguments: s), icon: const Icon(Icons.map_outlined), label: const Text('Åpne ruteoversikt')),
        ],
        if (official != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.publishRoute, arguments: PublishRouteArgs(stage: s)), icon: const Icon(Icons.public), label: const Text('Publiser rute')),
        ],
      ]),
    );
  }

  IconData _waypointIcon(StageWaypointKind kind) => switch (kind) {
        StageWaypointKind.poi => Icons.place_outlined,
        StageWaypointKind.stop => Icons.flag_outlined,
        StageWaypointKind.via => Icons.alt_route_rounded,
      };

  String _kindLabel(StageWaypointKind kind) => switch (kind) {
        StageWaypointKind.poi => 'POI',
        StageWaypointKind.stop => 'Stopp',
        StageWaypointKind.via => 'Via-punkt',
      };

  String _duration(int seconds) => '${seconds ~/ 3600} t ${((seconds % 3600) ~/ 60)} min';
}
