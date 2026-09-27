import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/transport_profiles.dart';
import '../theme/govia_theme.dart';

class RouteProfilePicker extends StatelessWidget {
  const RouteProfilePicker({
    super.key,
    required this.transport,
    required this.value,
    required this.onChanged,
  });

  final StageTransport transport;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = profilesForTransport(transport);
    final selected = options.where((option) => option.id == value).firstOrNull ?? options.first;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: options.length <= 1 ? null : () => _open(context, options),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ruteprofil',
          prefixIcon: const Icon(Icons.route_outlined),
          suffixIcon: options.length <= 1 ? const Icon(Icons.lock_outline) : const Icon(Icons.expand_more),
        ),
        child: Text(selected.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Future<void> _open(BuildContext context, List<RouteProfileOption> options) async {
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
              Text('${transportLabel(transport)} har egne profiler som bare bruker funksjoner GoVia faktisk støtter.', style: const TextStyle(color: GoViaColors.muted)),
              const SizedBox(height: 14),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: option.id == value ? GoViaColors.orange.withValues(alpha: .10) : GoViaColors.panel2,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      onTap: () => Navigator.pop(sheetContext, option.id),
                      title: Text(option.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(option.description),
                      trailing: option.id == value ? const Icon(Icons.check_circle, color: GoViaColors.orange) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

extension FirstOrNullRouteProfile<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
