import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class PublishedRouteDetailScreen extends StatelessWidget {
  const PublishedRouteDetailScreen({super.key, required this.route});
  final PublishedRoute? route;

  @override
  Widget build(BuildContext context) {
    final value = route;
    if (value == null) return const Scaffold(body: Center(child: Text('Ruten finnes ikke.')));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offentlig rute'),
        actions: [IconButton(onPressed: () => AppScope.of(context).setPublishedRouteFavorite(value, !value.saved), icon: Icon(value.saved ? Icons.bookmark : Icons.bookmark_outline))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          RouteMapCard(height: 280, points: value.geometry, connectPoints: value.geometry.length >= 2, label: value.title),
          const SizedBox(height: 16),
          Text(value.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${value.authorName} · ${transportLabel(value.transport)}', style: const TextStyle(color: GoViaColors.muted)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            StatusPill('${(value.distanceMeters / 1000).round()} km', icon: Icons.straighten),
            StatusPill(_duration(value.durationSeconds), icon: Icons.schedule),
            ...value.tags.map((tag) => StatusPill(tag)),
          ]),
          if (value.description.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(value.description),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () async {
              await AppScope.of(context).clonePublishedRoute(value);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Lagre som min rute'),
          ),
        ],
      ),
    );
  }

  String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0 ? '${hours}t ${rest}m' : '${rest}m';
  }
}
