import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final history = state.trips
        .where((trip) => trip.status == TripStatus.completed || trip.status == TripStatus.archived)
        .toList(growable: false)
      ..sort((a, b) => b.endDate.compareTo(a.endDate));

    return GoViaScreen(
      title: 'Historikk',
      child: history.isEmpty
          ? const _EmptyHistory()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Tidligere turer'),
                for (final trip in history) _HistoryTrip(trip),
              ],
            ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Icon(Icons.history, size: 42, color: GoViaColors.muted),
              const SizedBox(height: 12),
              Text('Ingen turhistorikk ennå', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Fullførte og arkiverte turer vises her. GoVia legger ikke inn demo-turer i produksjonsmodus.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GoViaColors.muted),
              ),
            ],
          ),
        ),
      );
}

class _HistoryTrip extends StatelessWidget {
  const _HistoryTrip(this.trip);
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final distanceMeters = trip.stages.fold<int>(0, (sum, stage) => sum + stage.distanceMeters);
    final durationSeconds = trip.stages.fold<int>(0, (sum, stage) => sum + stage.durationSeconds);
    final distance = distanceMeters > 0 ? '${(distanceMeters / 1000).round()} km' : 'Ingen distanse';
    final duration = _duration(durationSeconds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0x2210A9FF),
            child: Icon(Icons.two_wheeler, color: GoViaColors.blue),
          ),
          title: Text(trip.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${_date(trip.endDate)} · $distance · $duration'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/trip', arguments: trip),
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  String _duration(int seconds) {
    if (seconds <= 0) return 'Ingen kjøretid';
    final minutes = (seconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0 ? '${hours}t ${rest}m' : '${rest}m';
  }
}
