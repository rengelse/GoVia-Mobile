import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../domain/models.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  TripStatus selected = TripStatus.planned;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trips = state.trips.where((trip) => trip.status == selected).toList(growable: false)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final counts = <TripStatus, int>{
      for (final status in TripStatus.values) status: state.trips.where((trip) => trip.status == status).length,
    };

    return RefreshIndicator(
      onRefresh: state.refreshCloud,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Row(
            children: [
              Expanded(child: Text('Turer', style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(tooltip: 'Synkroniser', onPressed: state.refreshCloud, icon: const Icon(Icons.sync_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            state.offline ? 'Offline – viser sist lagrede data' : 'Alle dine turer samlet på ett sted',
            style: TextStyle(color: state.offline ? GoViaColors.orange : GoViaColors.muted),
          ),
          const SizedBox(height: 18),
          _StatusSelector(counts: counts, selected: selected, onSelected: (value) => setState(() => selected = value)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Text(_title(selected), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              Text('${trips.length}', style: const TextStyle(color: GoViaColors.muted, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          if (trips.isEmpty)
            _EmptyState(status: selected)
          else
            for (final trip in trips) ...[
              _TripCard(trip: trip),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  String _title(TripStatus status) => switch (status) {
        TripStatus.planned => 'Planlagte turer',
        TripStatus.active => 'Aktive turer',
        TripStatus.completed => 'Fullførte turer',
        TripStatus.archived => 'Arkiv',
      };
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.counts, required this.selected, required this.onSelected});
  final Map<TripStatus, int> counts;
  final TripStatus selected;
  final ValueChanged<TripStatus> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(TripStatus.planned, 'Planlagt'),
            _chip(TripStatus.active, 'Aktiv'),
            _chip(TripStatus.completed, 'Fullført'),
            _chip(TripStatus.archived, 'Arkiv'),
          ],
        ),
      );

  Widget _chip(TripStatus status, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected == status,
          onSelected: (_) => onSelected(status),
          label: Text('$label  ${counts[status] ?? 0}'),
        ),
      );
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final distanceMeters = trip.stages.fold<int>(0, (sum, stage) => sum + stage.distanceMeters);
    final durationSeconds = trip.stages.fold<int>(0, (sum, stage) => sum + stage.durationSeconds);
    final transport = trip.stages.isEmpty ? null : trip.stages.first.transport;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await AppScope.of(context).selectTrip(trip);
          if (context.mounted) {
            Navigator.pushNamed(context, '/trip', arguments: trip);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: GoViaColors.blue.withValues(alpha: .12),
                    child: Icon(_transportIcon(transport), color: GoViaColors.cyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 3),
                        Text('${trip.start} → ${trip.end}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GoViaColors.muted)),
                      ],
                    ),
                  ),
                  if (trip.offlineReady) const Icon(Icons.offline_pin, color: GoViaColors.green, size: 20),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Metric(icon: Icons.route_outlined, label: distanceMeters > 0 ? '${(distanceMeters / 1000).toStringAsFixed(distanceMeters >= 100000 ? 0 : 1)} km' : '${trip.stages.length} etapper'),
                  if (durationSeconds > 0) _Metric(icon: Icons.schedule_outlined, label: _duration(durationSeconds)),
                  _Metric(icon: Icons.group_outlined, label: '${trip.participants.length} deltakere'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _duration(int seconds) {
    final minutes = (seconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0 ? '${hours}t ${rest}m' : '${rest}m';
  }

  static IconData _transportIcon(StageTransport? transport) => switch (transport) {
        StageTransport.motorcycle => Icons.two_wheeler,
        StageTransport.car => Icons.directions_car_outlined,
        StageTransport.cycling => Icons.pedal_bike,
        StageTransport.walking => Icons.directions_walk,
        StageTransport.train => Icons.train_outlined,
        StageTransport.ferry => Icons.directions_boat_outlined,
        null => Icons.route_outlined,
      };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: GoViaColors.panel2, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: GoViaColors.muted),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status});
  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      TripStatus.planned => 'Ingen planlagte turer. Opprett en ny tur eller hent en fra Desktop.',
      TripStatus.active => 'Ingen tur er aktiv akkurat nå.',
      TripStatus.completed => 'Ingen fullførte turer ennå.',
      TripStatus.archived => 'Arkivet er tomt.',
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: GoViaColors.panel, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route_outlined, color: GoViaColors.muted, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: GoViaColors.muted, height: 1.4))),
        ],
      ),
    );
  }
}
