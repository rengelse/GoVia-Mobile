import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme/govia_theme.dart';
import '../core/updater/github_updater.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'app_scope.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _quietUpdateCheck());
  }

  Future<void> _quietUpdateCheck() async {
    if (!Platform.isAndroid || !mounted) return;
    final state = AppScope.of(context);
    final previous = int.tryParse(state.store.readString('last_update_check_ms') ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - previous < const Duration(hours: 12).inMilliseconds) return;
    await state.store.writeString('last_update_check_ms', '$now');
    try {
      final info = await GithubUpdater().check();
      if (info == null || !mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ny GoVia-versjon'),
          content: Text('GoVia Mobile ${info.version} er tilgjengelig. Vil du åpne oppdatering under Profil?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Senere')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Åpne')),
          ],
        ),
      );
      if (open == true && mounted) state.setShellIndex(2);
    } catch (_) {
      // Startup update checks are intentionally silent; manual checks expose errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const pages = [
      HomeScreen(),
      NotificationsScreen(embedded: true),
      ProfileScreen(embedded: true),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: state.shellIndex, children: pages),
      bottomNavigationBar: _GoViaBottomNavigation(
        selectedIndex: state.shellIndex,
        unreadCount: state.unreadNotificationCount,
        onSelected: state.setShellIndex,
      ),
    );
  }
}

class _GoViaBottomNavigation extends StatelessWidget {
  const _GoViaBottomNavigation({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: .18), blurRadius: 24, offset: Offset(0, -8))],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(10, 4, 10, 2),
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _ShellDestination(
                  index: 0,
                  selectedIndex: selectedIndex,
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map_rounded,
                  label: 'Kart',
                  onSelected: onSelected,
                ),
                _ShellDestination(
                  index: 1,
                  selectedIndex: selectedIndex,
                  icon: Icons.notifications_none_rounded,
                  selectedIcon: Icons.notifications_rounded,
                  label: 'Varsler',
                  badgeCount: unreadCount,
                  onSelected: onSelected,
                ),
                _ShellDestination(
                  index: 2,
                  selectedIndex: selectedIndex,
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profil',
                  onSelected: onSelected,
                ),
              ],
            ),
          ),
        ),
      );
}

class _ShellDestination extends StatelessWidget {
  const _ShellDestination({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onSelected,
    this.badgeCount = 0,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final color = selected ? GoViaColors.orange : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? selectedIcon : icon, color: color, size: 27),
                  if (badgeCount > 0)
                    Positioned(
                      right: -9,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GoViaColors.orange,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 32 : 0,
                height: 3,
                decoration: BoxDecoration(color: GoViaColors.orange, borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
