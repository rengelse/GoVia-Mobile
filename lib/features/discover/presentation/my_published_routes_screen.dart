import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';
import 'publish_route_screen.dart';

class MyPublishedRoutesScreen extends StatefulWidget {
  const MyPublishedRoutesScreen({super.key});

  @override
  State<MyPublishedRoutesScreen> createState() => _MyPublishedRoutesScreenState();
}

class _MyPublishedRoutesScreenState extends State<MyPublishedRoutesScreen> {
  bool loading = true;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await AppScope.of(context).refreshMyPublishedRoutes();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openEditor({PublishedRoute? route}) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.publishRoute,
      arguments: PublishRouteArgs(existingRoute: route),
    );
    if (mounted) await _refresh();
  }

  Future<void> _archive(PublishedRoute route) async {
    await AppScope.of(context).archivePublishedRoute(route);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruten er avpublisert.')));
  }

  Future<void> _republish(PublishedRoute route) async {
    await AppScope.of(context).updatePublishedRoute(
      route: route,
      title: route.title,
      description: route.description,
      tags: route.tags,
      visibility: route.visibility,
      status: 'published',
    );
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruten er publisert igjen.')));
  }

  Future<void> _delete(PublishedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slett publisert rute?'),
        content: Text('«${route.title}» slettes permanent fra Oppdag. Originalturen din påvirkes ikke.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Slett')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).deletePublishedRoute(route);
  }

  @override
  Widget build(BuildContext context) {
    final routes = AppScope.of(context).myPublishedRoutes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mine publiserte turer'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Publiser tur'),
      ),
      body: loading && routes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  if (routes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Column(
                          children: [
                            Icon(Icons.public_off_outlined, size: 42, color: GoViaColors.muted),
                            SizedBox(height: 12),
                            Text('Du har ikke publisert noen turer ennå.', style: TextStyle(fontWeight: FontWeight.w800)),
                            SizedBox(height: 6),
                            Text('Publiser en faktisk planlagt eller fullført GoVia-rute og del den som et eget snapshot.', textAlign: TextAlign.center, style: TextStyle(color: GoViaColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  for (final route in routes) ...[
                    _PublishedRouteCard(
                      route: route,
                      onOpen: () => Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: route),
                      onEdit: () => _openEditor(route: route),
                      onArchive: route.status == 'published' ? () => _archive(route) : null,
                      onRepublish: route.status == 'archived' ? () => _republish(route) : null,
                      onDelete: () => _delete(route),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PublishedRouteCard extends StatelessWidget {
  const _PublishedRouteCard({
    required this.route,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.onRepublish,
    required this.onDelete,
  });

  final PublishedRoute route;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onRepublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (route.photoUrls.isNotEmpty)
              Image.network(route.photoUrls.first, height: 150, width: double.infinity, fit: BoxFit.cover)
            else
              RouteMapCard(height: 150, points: route.geometry, label: transportLabel(route.transport)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(route.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                      StatusPill(
                        route.status == 'published' ? 'Publisert' : route.status == 'draft' ? 'Utkast' : 'Arkivert',
                        color: route.status == 'published' ? GoViaColors.green : GoViaColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${route.start} → ${route.end}', style: const TextStyle(color: GoViaColors.muted)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(transportLabel(route.transport), icon: Icons.route),
                      StatusPill(_visibilityLabel(route.visibility), color: GoViaColors.blue, icon: Icons.visibility_outlined),
                      StatusPill('${(route.distanceMeters / 1000).round()} km', color: GoViaColors.orange, icon: Icons.straighten),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(onPressed: onEdit, tooltip: 'Rediger', icon: const Icon(Icons.edit_outlined)),
                      if (onArchive != null) IconButton(onPressed: onArchive, tooltip: 'Avpubliser', icon: const Icon(Icons.public_off_outlined)),
                      if (onRepublish != null) IconButton(onPressed: onRepublish, tooltip: 'Publiser igjen', icon: const Icon(Icons.public_outlined)),
                      IconButton(onPressed: onDelete, tooltip: 'Slett', icon: const Icon(Icons.delete_outline)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _visibilityLabel(String value) => switch (value) {
        'private' => 'Privat',
        'unlisted' => 'Skjult lenke',
        _ => 'Offentlig',
      };
}
