import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class StagesScreen extends StatelessWidget {
  const StagesScreen({super.key, this.trip});
  final Trip? trip;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final value = trip ?? state.activeTrip;
    final stages = [...?value?.stages]
      ..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));

    return GoViaScreen(
      title: 'Etapper',
      subtitle: value?.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stages.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Denne turen har ingen etapper.'))),
          for (var index = 0; index < stages.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StageCard(stage: stages[index], number: index + 1),
            ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.number});
  final Stage stage;
  final int number;

  @override
  Widget build(BuildContext context) {
    final navigable = stage.transport != StageTransport.ferry && stage.transport != StageTransport.train;
    final statusLabel = switch (stage.status) {
      StageStatus.active => 'Aktiv',
      StageStatus.completed => 'Fullført',
      StageStatus.planned => 'Ikke startet',
    };
    final statusIcon = switch (stage.status) {
      StageStatus.active => Icons.navigation_rounded,
      StageStatus.completed => Icons.check_circle_outline,
      StageStatus.planned => Icons.schedule_outlined,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: GoViaColors.orange.withValues(alpha: .14),
                  child: Text('$number', style: const TextStyle(color: GoViaColors.orange, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.name.trim().isEmpty ? '${stage.start} → ${stage.end}' : stage.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('Dag ${stage.day} · ${transportLabel(stage.transport)} · $statusLabel'),
                    ],
                  ),
                ),
                Icon(statusIcon, color: stage.status == StageStatus.completed ? GoViaColors.green : GoViaColors.orange),
              ],
            ),
            if (stage.name.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${stage.start} → ${stage.end}'),
            ],
            if (stage.waypoints.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${stage.stops.length} stopp · ${stage.pois.length} POI · ${stage.viaPoints.length} via-punkt'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.stage, arguments: stage),
                    child: const Text('Detaljer'),
                  ),
                ),
                if (navigable) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await AppScope.of(context).startNavigationStage(stage);
                        if (context.mounted) Navigator.pushNamed(context, AppRoutes.navigation, arguments: stage);
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(stage.status == StageStatus.completed ? 'Kjør igjen' : 'Start etappe'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
