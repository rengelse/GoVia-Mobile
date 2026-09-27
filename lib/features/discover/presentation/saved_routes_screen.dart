import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../domain/models.dart';

class SavedRoutesScreen extends StatelessWidget {
  const SavedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routes = AppScope.of(context).publishedRoutes.where((route) => route.saved).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Lagrede ruter')),
      body: routes.isEmpty
          ? const Center(child: Text('Ingen lagrede community-ruter ennå.'))
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                for (final route in routes)
                  Card(
                    child: ListTile(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: route),
                      title: Text(route.title),
                      subtitle: Text('${transportLabel(route.transport)} · ${route.start} → ${route.end}'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
              ],
            ),
    );
  }
}
