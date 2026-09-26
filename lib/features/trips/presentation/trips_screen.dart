import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../domain/models.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(padding: const EdgeInsets.fromLTRB(18,18,18,110), children: [
      Row(children: [Expanded(child: Text('Mine turer', style: Theme.of(context).textTheme.headlineMedium)), IconButton(onPressed: state.refreshCloud, icon: const Icon(Icons.sync_rounded))]),
      const SizedBox(height: 5), Text(state.offline ? 'Offline – viser lokal data' : 'Synkronisert med GoVia', style: TextStyle(color: state.offline ? GoViaColors.orange : GoViaColors.muted)),
      const SizedBox(height: 18),
      if (state.trips.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Ingen turer ennå. Opprett en ny tur eller hent en fra Desktop.'))),
      for (final trip in state.trips) ...[_TripCard(trip: trip), const SizedBox(height: 12)],
      const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.history), icon: const Icon(Icons.history), label: const Text('Se turhistorikk')),
    ]);
  }
}
class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip}); final Trip trip;
  @override Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () async { await AppScope.of(context).selectTrip(trip); if (context.mounted) Navigator.pushNamed(context, AppRoutes.trip, arguments: trip); }, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(trip.name, style: Theme.of(context).textTheme.titleLarge)), if (trip.offlineReady) const Icon(Icons.offline_pin, color: GoViaColors.green)]),
    const SizedBox(height: 7), Text('${trip.start} → ${trip.end}', style: const TextStyle(color: GoViaColors.muted)), const SizedBox(height: 12), Row(children: [Icon(Icons.route, size: 17, color: GoViaColors.orange), const SizedBox(width: 6), Text('${trip.stages.length} etapper'), const SizedBox(width: 18), const Icon(Icons.group_outlined, size: 17, color: GoViaColors.blue), const SizedBox(width: 6), Text('${trip.participants.length} deltakere')])
  ]))));
}
