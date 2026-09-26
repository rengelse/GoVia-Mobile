import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final people = AppScope.of(context).activeTrip?.participants ?? const [];
    return GoViaScreen(
      title: 'Deltakere',
      child: Column(
        children: [
          for (final p in people)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name[0])),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(p.role == 'owner' ? 'Tureier' : 'Deltaker'),
                  trailing: StatusPill(
                    p.online ? 'Online' : 'Offline',
                    color: p.online ? GoViaColors.green : GoViaColors.muted,
                  ),
                  onTap: () => _openProfile(context, p.name, p.role),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openProfile(BuildContext context, String name, String role) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 28, child: Text(name.isEmpty ? '?' : name[0], style: const TextStyle(fontSize: 22))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(sheetContext).textTheme.titleLarge),
                      Text(role == 'owner' ? 'Tureier' : 'Deltaker', style: const TextStyle(color: GoViaColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Kort profil', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Profilfelter og avatar hentes fra GoVia-profilen når mobil snapshot-kontrakten er låst.'),
          ],
        ),
      ),
    );
  }
}
