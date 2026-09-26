import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class StageDetailScreen extends StatelessWidget {
  const StageDetailScreen({super.key, this.stage}); final Stage? stage;
  @override Widget build(BuildContext context) {
    final stages = AppScope.of(context).activeTrip?.stages ?? const <Stage>[];
    final s = stage ?? (stages.isEmpty ? null : stages.first);
    if (s == null) return const GoViaScreen(title: 'Etappe', child: Text('Ingen etappe valgt.'));
    final ferry = s.transport == StageTransport.ferry;
    RouteCandidate? official;
    for (final candidate in s.routeCandidates) {
      if (candidate.id == s.officialRouteId || (official == null && candidate.official)) official = candidate;
    }
    return GoViaScreen(title: 'Dag ${s.day}', subtitle: '${s.start} → ${s.end}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RouteMapCard(height: 260, points: official?.geometry ?? const [], label: ferry ? 'Ferge' : 'Offisiell rute'), const SizedBox(height: 16),
      Row(children: [StatusPill(transportLabel(s.transport), color: ferry ? GoViaColors.blue : GoViaColors.orange, icon: ferry ? Icons.directions_boat_filled_outlined : Icons.two_wheeler), if (s.officialRouteId != null) ...[const SizedBox(width: 8), const StatusPill('Offisiell rute', color: GoViaColors.green, icon: Icons.check_circle_outline)]]),
      const SizedBox(height: 18), Text('${s.start} → ${s.end}', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 16),
      if (!ferry) Row(children: [MetricCard(label: 'Distanse', value: '${(s.distanceMeters/1000).round()} km', icon: Icons.straighten, color: GoViaColors.orange), const SizedBox(width: 10), MetricCard(label: 'Tid', value: _duration(s.durationSeconds), icon: Icons.schedule)]),
      if (ferry) const Card(child: Padding(padding: EdgeInsets.all(18), child: Row(children: [Icon(Icons.directions_boat, color: GoViaColors.blue), SizedBox(width: 12), Expanded(child: Text('Fergeetappen bruker terminalpunktene og skal aldri beregnes som en bilrute rundt sjøen.'))]))),
      const SizedBox(height: 22), FilledButton.icon(onPressed: ferry ? null : () => Navigator.pushNamed(context, AppRoutes.routeOverview, arguments: s), icon: const Icon(Icons.map_outlined), label: Text(ferry ? 'Navigasjon ikke relevant for ferge' : 'Åpne ruteoversikt')),
      const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.poi), icon: const Icon(Icons.place_outlined), label: const Text('Stopp og POI')),
    ]));
  }
  String _duration(int seconds) => '${seconds ~/ 3600} t ${((seconds % 3600) ~/ 60)} min';
}
