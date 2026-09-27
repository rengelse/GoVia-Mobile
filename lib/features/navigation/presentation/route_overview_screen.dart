import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class RouteOverviewScreen extends StatefulWidget {
  const RouteOverviewScreen({super.key, this.stage}); final Stage? stage;
  @override State<RouteOverviewScreen> createState() => _RouteOverviewScreenState();
}
class _RouteOverviewScreenState extends State<RouteOverviewScreen> {
  String? selected;
  @override Widget build(BuildContext context) {
    final trip = AppScope.of(context).activeTrip;
    final s = widget.stage ?? (trip != null && trip.stages.isNotEmpty ? trip.stages.first : null);
    if (s == null) return const GoViaScreen(title: 'Rute', child: Text('Ingen rute tilgjengelig.'));
    final candidates = s.routeCandidates;
    selected ??= s.officialRouteId ?? (candidates.isNotEmpty ? candidates.first.id : null);
    RouteCandidate? preview;
    for (final candidate in candidates) { if (candidate.id == selected) preview = candidate; }
    return GoViaScreen(title: 'Ruteoversikt', subtitle: '${s.start} → ${s.end}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RouteMapCard(height: 310, points: preview?.geometry ?? const [], label: candidates.length > 1 ? '${candidates.length} rutealternativer' : 'Offisiell rute'),
      const SizedBox(height: 18),
      if (candidates.length > 1) ...[
        const SectionTitle('Rutealternativer'),
        for (final c in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Card(
              child: ListTile(
                onTap: () => setState(() => selected = c.id),
                leading: Icon(
                  selected == c.id ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected == c.id ? GoViaColors.orange : GoViaColors.muted,
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (c.official) const StatusPill('Offisiell', color: GoViaColors.green),
                  ],
                ),
                subtitle: Text('${(c.distanceMeters / 1000).round()} km · ${_duration(c.durationSeconds)}'),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.offline), icon: const Icon(Icons.download_for_offline_outlined), label: const Text('Last ned'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: () async { await AppScope.of(context).startNavigationStage(s); if (context.mounted) Navigator.pushNamed(context, AppRoutes.navigation, arguments: s); }, icon: const Icon(Icons.navigation_rounded), label: const Text('Start navigasjon')))]),
      const SizedBox(height: 18), const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: GoViaColors.blue), SizedBox(width: 10), Expanded(child: Text('Ved avvik skal GoVia føre deg tilbake til den offisielle ruten. Større omruting skal aldri erstatte den planlagte ruten uten at du velger det.'))]))),
    ]));
  }
  String _duration(int s) => '${s ~/ 3600} t ${((s % 3600) ~/ 60)} min';
}
