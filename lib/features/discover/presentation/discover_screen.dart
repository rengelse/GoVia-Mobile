import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  StageTransport? filter;
  bool refreshing = false;
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (refreshing) return;
    refreshing = true;
    await AppScope.of(context).refreshPublishedRoutes(transport: filter);
    if (mounted) setState(() => refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final routes = state.publishedRoutes.where((route) => filter == null || route.transport == filter).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oppdag'),
        actions: [
          IconButton(tooltip: 'Oppdater', onPressed: refreshing ? null : _refresh, icon: refreshing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Lagrede ruter',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.savedRoutes),
            icon: const Icon(Icons.bookmark_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const RouteMapCard(height: 210, label: 'Finn ruter og turer fra GoVia-fellesskapet'),
          const SizedBox(height: 16),
          Text('Transport', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('Alle'), selected: filter == null, onSelected: (_) { setState(() => filter = null); _refresh(); }),
              for (final value in StageTransport.values)
                ChoiceChip(
                  label: Text(transportLabel(value)),
                  selected: filter == value,
                  onSelected: (_) { setState(() => filter = value); _refresh(); },
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (routes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.explore_outlined, size: 44, color: GoViaColors.cyan),
                    const SizedBox(height: 12),
                    const Text('Ingen publiserte ruter ennå', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    const Text(
                      'Oppdag er klar i mobilklienten. Offentlige ruter vises her når community-backenden er koblet til.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GoViaColors.muted),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final route in routes)
              Card(
                child: ListTile(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: route),
                  leading: CircleAvatar(child: Icon(_iconFor(route.transport))),
                  title: Text(route.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${transportLabel(route.transport)} · ${route.start} → ${route.end}'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
        ],
      ),
    );
  }

  IconData _iconFor(StageTransport value) => switch (value) {
        StageTransport.motorcycle => Icons.two_wheeler,
        StageTransport.car => Icons.directions_car,
        StageTransport.walking => Icons.directions_walk,
        StageTransport.cycling => Icons.pedal_bike,
        StageTransport.train => Icons.train,
        StageTransport.ferry => Icons.directions_boat,
      };
}
