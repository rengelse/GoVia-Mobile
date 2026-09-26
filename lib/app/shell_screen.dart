import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/govia_theme.dart';
import '../core/updater/github_updater.dart';
import '../features/group/presentation/group_live_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/new_trip/presentation/new_trip_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/trips/presentation/trips_screen.dart';
import 'app_scope.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override State<ShellScreen> createState() => _ShellScreenState();
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
      if (open == true && mounted) state.setShellIndex(4);
    } catch (_) {
      // Startup update checks are intentionally silent; manual checks expose errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const pages = [
      HomeScreen(),
      TripsScreen(),
      NewTripScreen(embedded: true),
      GroupLiveScreen(embedded: true),
      ProfileScreen(embedded: true),
    ];
    return Scaffold(
      body: IndexedStack(index: state.shellIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.shellIndex,
        onDestinationSelected: state.setShellIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Hjem'),
          NavigationDestination(icon: Icon(Icons.luggage_outlined), selectedIcon: Icon(Icons.luggage), label: 'Turer'),
          NavigationDestination(icon: _PlusIcon(), label: 'Ny tur'),
          NavigationDestination(icon: Icon(Icons.groups_2_outlined), selectedIcon: Icon(Icons.groups_2), label: 'Gruppe'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _PlusIcon extends StatelessWidget {
  const _PlusIcon();
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: GoViaColors.orange, shape: BoxShape.circle),
        child: const Icon(Icons.add, color: Colors.white),
      );
}
