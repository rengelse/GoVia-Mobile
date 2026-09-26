import 'package:flutter/material.dart';
import '../theme/govia_theme.dart';

class RouteProfilePicker extends StatelessWidget {
  const RouteProfilePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabledProfiles = const {'Raskest'},
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Set<String> enabledProfiles;

  static const _profiles = <({String name, String subtitle, IconData icon})>[
    (name: 'Raskest', subtitle: 'Prioriterer kortest kjøretid.', icon: Icons.bolt_outlined),
    (name: 'Balansert', subtitle: 'Balanse mellom tid og interessante veier.', icon: Icons.tune),
    (name: 'Svingete', subtitle: 'Prioriterer mer svingete MC-veier.', icon: Icons.gesture),
    (name: 'Maks svingete', subtitle: 'Mest mulig svingete rute.', icon: Icons.route_outlined),
  ];

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Ruteprofil',
            prefixIcon: Icon(Icons.route_outlined),
            suffixIcon: Icon(Icons.expand_more),
          ),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: GoViaColors.panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Velg ruteprofil', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Profilen bestemmer hvordan GoVia prioriterer veiene.',
                style: TextStyle(color: GoViaColors.muted),
              ),
              const SizedBox(height: 14),
              for (final profile in _profiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ProfileTile(
                    name: profile.name,
                    subtitle: profile.subtitle,
                    icon: profile.icon,
                    selected: profile.name == value,
                    enabled: enabledProfiles.contains(profile.name),
                    onTap: () => Navigator.pop(sheetContext, profile.name),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && enabledProfiles.contains(selected)) onChanged(selected);
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? GoViaColors.orange.withValues(alpha: .10) : GoViaColors.panel2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: enabled ? GoViaColors.orange : GoViaColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
                          if (selected) const Icon(Icons.check_circle, color: GoViaColors.green, size: 20),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enabled ? subtitle : '$subtitle Kommer når serverprofilen er tilgjengelig.',
                        style: const TextStyle(color: GoViaColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
