import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trip = state.activeTrip;
    if (trip == null) {
      return _empty(context);
    }
    final stages = [...trip.stages]..sort((a,b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    final today = stages.isEmpty ? null : stages.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Row(children: [const Expanded(child: GoViaLogo(compact: true)), IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications), icon: const Icon(Icons.notifications_none_rounded))]),
        const SizedBox(height: 22),
        Text('God tur', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        const Text('Alt du trenger for dagens etappe.', style: TextStyle(color: GoViaColors.muted)),
        const SizedBox(height: 18),
        RouteMapCard(height: 230, label: trip.name),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(trip.name, style: Theme.of(context).textTheme.titleLarge)), StatusPill(trip.offlineReady ? 'Offline klar' : 'Kun online', color: trip.offlineReady ? GoViaColors.green : GoViaColors.orange, icon: trip.offlineReady ? Icons.offline_pin : Icons.cloud_outlined)]),
          const SizedBox(height: 7), Text('${trip.start} → ${trip.end}', style: const TextStyle(color: GoViaColors.muted)),
          if (today != null) ...[
            const SizedBox(height: 18), Text('Dag ${today.day}', style: const TextStyle(color: GoViaColors.orange, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5), Text('${today.start} → ${today.end}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 14), FilledButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.stage, arguments: today), icon: const Icon(Icons.route), label: const Text('Åpne dagens etappe')),
          ],
        ]))),
        const SizedBox(height: 20),
        const SectionTitle('Snarveier'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _quick(context, Icons.groups_2_outlined, 'Gruppe live', AppRoutes.groupLive),
          _quick(context, Icons.cloud_outlined, 'Vær', AppRoutes.weather),
          _quick(context, Icons.download_for_offline_outlined, 'Offline', AppRoutes.offline),
          _quick(context, Icons.place_outlined, 'Stopp / POI', AppRoutes.poi),
        ]),
      ],
    );
  }
  Widget _quick(BuildContext context, IconData icon, String label, String route) => SizedBox(width: (MediaQuery.sizeOf(context).width - 46) / 2, child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, route), icon: Icon(icon), label: Text(label), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), side: const BorderSide(color: GoViaColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));
  Widget _empty(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [const GoViaLogo(), const SizedBox(height: 48), Text('Ingen aktiv tur', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 10), const Text('Opprett en tur på mobilen eller hent en ferdig plan fra GoVia Desktop.', style: TextStyle(color: GoViaColors.muted)), const SizedBox(height: 20), FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.newTrip), child: const Text('Ny tur'))]);
}
