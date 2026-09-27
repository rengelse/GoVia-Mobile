import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  TripStatus selected = TripStatus.completed;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final counts = {for (final status in TripStatus.values) status: state.trips.where((trip) => trip.status == status).length};
    final visible = state.trips.where((trip) => trip.status == selected).toList(growable: false)
      ..sort((a, b) {
        final left = selected == TripStatus.completed || selected == TripStatus.archived ? a.endDate : a.startDate;
        final right = selected == TripStatus.completed || selected == TripStatus.archived ? b.endDate : b.startDate;
        return right.compareTo(left);
      });

    return GoViaScreen(
      title: 'Mine turer',
      actions: [
        IconButton(
          tooltip: 'Synkroniser',
          onPressed: state.loading ? null : () => state.refreshCloud(),
          icon: const Icon(Icons.sync),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryGrid(counts: counts, selected: selected, onSelected: (status) => setState(() => selected = status)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: SectionTitle(_statusTitle(selected))),
              if (state.offline) const StatusPill('Offline', color: GoViaColors.orange, icon: Icons.cloud_off_outlined),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            _EmptyStatus(status: selected)
          else
            for (final trip in visible) _TripHistoryCard(trip: trip),
          if (selected == TripStatus.completed) ...[
            const SizedBox(height: 18),
            const _HistoryIntegrityNote(),
          ],
        ],
      ),
    );
  }

  String _statusTitle(TripStatus status) => switch (status) {
        TripStatus.planned => 'Planlagte turer',
        TripStatus.active => 'Pågående turer',
        TripStatus.completed => 'Fullførte turer',
        TripStatus.archived => 'Arkiverte turer',
      };
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.counts, required this.selected, required this.onSelected});

  final Map<TripStatus, int> counts;
  final TripStatus selected;
  final ValueChanged<TripStatus> onSelected;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.85,
        children: [
          _StatusCard(status: TripStatus.planned, label: 'Planlagt', value: counts[TripStatus.planned] ?? 0, icon: Icons.event_outlined, selected: selected == TripStatus.planned, onTap: onSelected),
          _StatusCard(status: TripStatus.active, label: 'Pågående', value: counts[TripStatus.active] ?? 0, icon: Icons.navigation_outlined, selected: selected == TripStatus.active, onTap: onSelected),
          _StatusCard(status: TripStatus.completed, label: 'Fullført', value: counts[TripStatus.completed] ?? 0, icon: Icons.check_circle_outline, selected: selected == TripStatus.completed, onTap: onSelected),
          _StatusCard(status: TripStatus.archived, label: 'Arkivert', value: counts[TripStatus.archived] ?? 0, icon: Icons.archive_outlined, selected: selected == TripStatus.archived, onTap: onSelected),
        ],
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.label, required this.value, required this.icon, required this.selected, required this.onTap});

  final TripStatus status;
  final String label;
  final int value;
  final IconData icon;
  final bool selected;
  final ValueChanged<TripStatus> onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? GoViaColors.blue.withValues(alpha: .15) : GoViaColors.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onTap(status),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: selected ? GoViaColors.cyan : GoViaColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text(label, style: TextStyle(color: selected ? Colors.white : GoViaColors.muted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyStatus extends StatelessWidget {
  const _EmptyStatus({required this.status});
  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      TripStatus.planned => 'Ingen planlagte turer.',
      TripStatus.active => 'Ingen tur er aktiv akkurat nå.',
      TripStatus.completed => 'Ingen fullførte turer ennå. En tur havner her først når siste etappe faktisk er fullført.',
      TripStatus.archived => 'Ingen arkiverte turer.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.route_outlined, size: 34, color: GoViaColors.muted),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: const TextStyle(color: GoViaColors.muted, height: 1.45))),
          ],
        ),
      ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final distanceMeters = trip.stages.fold<int>(0, (sum, stage) => sum + stage.distanceMeters);
    final durationSeconds = trip.stages.fold<int>(0, (sum, stage) => sum + stage.durationSeconds);
    final transport = trip.stages.isEmpty ? null : trip.stages.first.transport;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/trip', arguments: trip),
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
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Metric(icon: Icons.calendar_today_outlined, label: _date(trip.status == TripStatus.completed || trip.status == TripStatus.archived ? trip.endDate : trip.startDate)),
                    _Metric(icon: Icons.straighten, label: distanceMeters > 0 ? '${(distanceMeters / 1000).toStringAsFixed(distanceMeters >= 100000 ? 0 : 1)} km' : 'Distanse mangler'),
                    _Metric(icon: Icons.schedule, label: _duration(durationSeconds)),
                    if (transport != null) _Metric(icon: _transportIcon(transport), label: transportLabel(transport)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  static String _duration(int seconds) {
    if (seconds <= 0) return 'Tid mangler';
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

class _HistoryIntegrityNote extends StatelessWidget {
  const _HistoryIntegrityNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: GoViaColors.panel2, borderRadius: BorderRadius.circular(14)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined, color: GoViaColors.green, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fullført betyr at siste etappe er avsluttet. Lagrede community-ruter og kataloginnhold legges ikke automatisk i historikken.',
                style: TextStyle(color: GoViaColors.muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
