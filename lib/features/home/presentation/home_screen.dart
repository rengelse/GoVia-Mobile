import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_state.dart';
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
      return _empty(context, state);
    }
    final stages = [...trip.stages]..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    final today = stages.isEmpty ? null : stages.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Row(
          children: [
            const Expanded(child: GoViaLogo(compact: true)),
            _NotificationButton(
              count: state.unreadNotificationCount,
              onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Aktiv tur', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        const Text('Det viktigste for turen du holder på med.', style: TextStyle(color: GoViaColors.muted)),
        const SizedBox(height: 18),
        RouteMapCard(height: 240, label: trip.name),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(trip.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                    StatusPill(trip.offlineReady ? 'Offline klar' : 'Online', color: trip.offlineReady ? GoViaColors.green : GoViaColors.orange, icon: trip.offlineReady ? Icons.offline_pin : Icons.cloud_outlined),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${trip.start} → ${trip.end}', style: const TextStyle(color: GoViaColors.muted)),
                if (today != null) ...[
                  const SizedBox(height: 16),
                  Text('Dag ${today.day} · ${today.start} → ${today.end}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.stage, arguments: today),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Fortsett turen'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle('På tur'),
        _ActionListTile(icon: Icons.groups_2_outlined, title: 'Gruppe live', subtitle: 'Se deltakere og del posisjon', onTap: () => Navigator.pushNamed(context, AppRoutes.groupLive)),
        _ActionListTile(icon: Icons.cloud_outlined, title: 'Vær', subtitle: 'Vær langs turen', onTap: () => Navigator.pushNamed(context, AppRoutes.weather)),
        _ActionListTile(icon: Icons.place_outlined, title: 'Stopp og POI', subtitle: 'Finn stopp langs ruta', onTap: () => Navigator.pushNamed(context, AppRoutes.poi)),
      ],
    );
  }

  Widget _empty(BuildContext context, AppState state) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 110),
        children: [
          Row(
            children: [
              const Expanded(child: GoViaLogo()),
              _NotificationButton(
                count: state.unreadNotificationCount,
                onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
              ),
            ],
          ),
          const SizedBox(height: 46),
          Text('Hva vil du gjøre?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Start med én handling. Alt annet finner du i Turer eller Oppdag.', style: TextStyle(color: GoViaColors.muted, height: 1.4)),
          const SizedBox(height: 22),
          _PrimaryAction(icon: Icons.add_road_outlined, title: 'Planlegg en tur', subtitle: 'Lag en ny tur fra start til mål', onTap: () => Navigator.pushNamed(context, AppRoutes.newTrip)),
          const SizedBox(height: 10),
          _PrimaryAction(icon: Icons.explore_outlined, title: 'Oppdag ruter', subtitle: 'Finn lokale og globale community-ruter', onTap: () => state.setShellIndex(3)),
          const SizedBox(height: 10),
          _PrimaryAction(icon: Icons.luggage_outlined, title: 'Mine turer', subtitle: 'Planlagt, aktivt, fullført og arkiv', onTap: () => state.setShellIndex(1)),
        ],
      );
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: GoViaColors.panel,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            onTap: onTap,
            leading: Icon(icon, color: GoViaColors.cyan),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle, style: const TextStyle(color: GoViaColors.muted)),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: GoViaColors.panel,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          minVerticalPadding: 16,
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: GoViaColors.blue.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: GoViaColors.cyan),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle, style: const TextStyle(color: GoViaColors.muted)),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}


class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(onPressed: onTap, icon: const Icon(Icons.notifications_none_rounded)),
          if (count > 0)
            Positioned(
              right: 3,
              top: 2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: GoViaColors.orange,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GoViaColors.bg, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      );
}
