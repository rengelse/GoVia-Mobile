import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, this.trip});
  final Trip? trip;
  @override Widget build(BuildContext context) {
    final value = trip ?? AppScope.of(context).activeTrip;
    if (value == null) return const GoViaScreen(title: 'Tur', child: Text('Ingen tur valgt.'));
    final stages = [...value.stages]..sort((a,b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    return GoViaScreen(title: value.name, actions: [IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.offline), icon: const Icon(Icons.download_for_offline_outlined))], child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RouteMapCard(height: 250, points: _tripGeometry(stages), label: '${value.start} → ${value.end}'), const SizedBox(height: 16),
      if (value.status == TripStatus.planned && stages.isNotEmpty && stages.first.transport != StageTransport.ferry) ...[
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final first = stages.first;
              await AppScope.of(context).startNavigationStage(first);
              if (context.mounted) Navigator.pushNamed(context, AppRoutes.navigation, arguments: first);
            },
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('Start tur'),
          ),
        ),
        const SizedBox(height: 14),
      ],
      Row(children: [MetricCard(label: 'Etapper', value: '${stages.length}', icon: Icons.route, color: GoViaColors.orange), const SizedBox(width: 10), MetricCard(label: 'Deltakere', value: '${value.participants.length}', icon: Icons.groups_2_outlined)]),
      const SizedBox(height: 22), SectionTitle('Etapper', trailing: TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.stages, arguments: value), child: const Text('Alle'))),
      for (final s in stages) _stageRow(context, s),
      const SizedBox(height: 16), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.participants), icon: const Icon(Icons.group_outlined), label: const Text('Deltakere'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.weather), icon: const Icon(Icons.cloud_outlined), label: const Text('Vær')))]),
    ]));
  }

  List<GeoPoint> _tripGeometry(List<Stage> stages) {
    final out = <GeoPoint>[];
    for (final stage in stages) {
      RouteCandidate? official;
      for (final candidate in stage.routeCandidates) {
        if (candidate.id == stage.officialRouteId || (official == null && candidate.official)) official = candidate;
      }
      for (final point in official?.geometry ?? const <GeoPoint>[]) {
        if (out.isEmpty || out.last.lat != point.lat || out.last.lon != point.lon) out.add(point);
      }
    }
    return out;
  }

  Widget _stageRow(BuildContext context, Stage s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: ListTile(onTap: () => Navigator.pushNamed(context, AppRoutes.stage, arguments: s), leading: CircleAvatar(backgroundColor: GoViaColors.orange.withValues(alpha: .14), child: Text('${s.day}', style: const TextStyle(color: GoViaColors.orange, fontWeight: FontWeight.w900))), title: Text('${s.start} → ${s.end}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Dag ${s.day} · ${transportLabel(s.transport)}'), trailing: const Icon(Icons.chevron_right))));
}
