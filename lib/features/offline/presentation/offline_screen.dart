import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../core/storage/offline_map_service.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});
  @override State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  double progress = 0;
  bool downloading = false;
  int bytes = 0;
  String? message;

  List<GeoPoint> _officialGeometry(Trip trip) {
    final out = <GeoPoint>[];
    final stages = [...trip.stages]..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    for (final stage in stages) {
      RouteCandidate? official;
      for (final candidate in stage.routeCandidates) {
        if (candidate.id == stage.officialRouteId || (official == null && candidate.official)) official = candidate;
      }
      if (official != null) out.addAll(official.geometry);
    }
    return out;
  }

  Future<void> _download(Trip trip) async {
    final geometry = _officialGeometry(trip);
    if (geometry.length < 2) {
      setState(() => message = 'Turen mangler offisiell route geometry. Synkroniser/beregn ruten før offlinekart lastes ned.');
      return;
    }
    setState(() { downloading = true; progress = 0; bytes = 0; message = null; });
    try {
      await OfflineMapService().downloadTripRegion(
        tripId: trip.id,
        name: trip.name,
        geometry: geometry,
        onProgress: (value, downloadedBytes) {
          if (mounted) setState(() { final normalized = value > 1 ? value / 100 : value; progress = normalized.clamp(0.0, 1.0); if (downloadedBytes > 0) bytes = downloadedBytes; });
        },
      );
      if (mounted) setState(() => message = 'Offlinekart er ferdig lastet ned.');
    } catch (e) {
      if (mounted) setState(() => message = 'Offlinekart feilet: $e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = AppScope.of(context).activeTrip;
    return GoViaScreen(
      title: 'Offline nedlasting',
      subtitle: trip?.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RouteMapCard(height: 220, points: trip == null ? const [] : _officialGeometry(trip), label: 'Offline-korridor'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip?.name ?? 'Valgt tur', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  const _OfflineRow(Icons.route, 'Etapper og offisiell rute', 'Lokal cache'),
                  const _OfflineRow(Icons.turn_right_rounded, 'Turn-by-turn manøvre', 'Venter på serverkontrakt'),
                  const _OfflineRow(Icons.place_outlined, 'Planlagte stopp / POI', 'Lokal cache'),
                  const _OfflineRow(Icons.cloud_outlined, 'Siste vær-snapshot', 'Lokal cache'),
                  const _OfflineRow(Icons.map_outlined, 'OpenFreeMap / MapLibre', 'Native offline region'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (downloading || progress > 0) ...[
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 7),
            Text('${(progress * 100).round()} %${bytes > 0 ? ' · ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : ''}', style: const TextStyle(color: GoViaColors.muted)),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: downloading || trip == null ? null : () => _download(trip),
            icon: const Icon(Icons.download_for_offline_outlined),
            label: Text(downloading ? 'Laster ned…' : progress >= 1 ? 'Last ned på nytt' : 'Last ned tur'),
          ),
          if (message != null) ...[const SizedBox(height: 12), Text(message!, style: TextStyle(color: message!.contains('ferdig') ? GoViaColors.green : GoViaColors.orange))],
          const SizedBox(height: 14),
          const Text('Kartregionen beregnes fra offisiell route geometry. Store turer bruker automatisk lavere makszoom for å unngå absurd store nedlastinger.', style: TextStyle(color: GoViaColors.muted)),
        ],
      ),
    );
  }
}

class _OfflineRow extends StatelessWidget {
  const _OfflineRow(this.icon, this.label, this.status);
  final IconData icon;
  final String label;
  final String status;
  @override Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Icon(icon, size: 20, color: GoViaColors.blue), const SizedBox(width: 10), Expanded(child: Text(label)), Text(status, style: const TextStyle(color: GoViaColors.muted, fontSize: 12))]),
      );
}
