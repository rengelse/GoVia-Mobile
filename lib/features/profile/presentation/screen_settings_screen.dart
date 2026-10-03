import 'package:flutter/material.dart';
import '../../../core/display/screen_preferences.dart';

class ScreenSettingsScreen extends StatefulWidget {
  const ScreenSettingsScreen({super.key});
  @override
  State<ScreenSettingsScreen> createState() => _ScreenSettingsScreenState();
}

class _ScreenSettingsScreenState extends State<ScreenSettingsScreen> {
  bool _saving = false;
  Future<void> _save(ScreenPreferences value) async {
    final controller = ScreenPreferencesScope.maybeOf(context);
    if (_saving || controller == null) { return; }
    setState(() => _saving = true);
    try { await controller.save(value); }
    catch (_) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunne ikke lagre skjermvalget. Prøv igjen.'))); }
    } finally { if (mounted) { setState(() => _saving = false); } }
  }

  @override
  Widget build(BuildContext context) {
    final value = ScreenPreferencesScope.maybeOf(context)?.value ?? const ScreenPreferences();
    return Scaffold(appBar: AppBar(title: const Text('Skjerm og kart')), body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
        Text('Skjerm', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<ScreenOrientation>(
          initialValue: value.orientation,
          decoration: const InputDecoration(labelText: 'Skjermretning'),
          items: const [DropdownMenuItem(value: ScreenOrientation.automatic, child: Text('Automatisk')),
            DropdownMenuItem(value: ScreenOrientation.portrait, child: Text('Stående')),
            DropdownMenuItem(value: ScreenOrientation.landscape, child: Text('Liggende'))],
          onChanged: _saving ? null : (next) { if (next != null) { _save(value.copyWith(orientation: next)); } }),
        const SizedBox(height: 8),
        Text('Operativsystemet kan overstyre skjermretning på nettbrett og i flervindusmodus.',
          style: Theme.of(context).textTheme.bodySmall),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Hold skjermen på'),
          subtitle: const Text('Mens aktiv navigasjon eller opptak vises på mobilen'), value: value.keepAwake,
          onChanged: _saving ? null : (next) => _save(value.copyWith(keepAwake: next))),
        const Divider(height: 32),
        Text('Kart under navigasjon', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<PhoneMapMode>(initialValue: value.mapMode,
          decoration: const InputDecoration(labelText: 'Standard kartmodus'),
          items: const [DropdownMenuItem(value: PhoneMapMode.perspective, child: Text('Perspektiv · følg')),
            DropdownMenuItem(value: PhoneMapMode.northUp, child: Text('Nord opp')),
            DropdownMenuItem(value: PhoneMapMode.overview, child: Text('Oversikt'))],
          onChanged: _saving ? null : (next) { if (next != null) { _save(value.copyWith(mapMode: next)); } }),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Automatisk zoom'),
          subtitle: const Text('Tilpass zoom til hastighet og neste manøver'), value: value.autoZoom,
          onChanged: _saving ? null : (next) => _save(value.copyWith(autoZoom: next))),
        const Divider(height: 32),
        Text('Vis under navigasjon', style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Fartsgrense'),
          subtitle: const Text('Vises når ruten har kjent fartsgrense'), value: value.showSpeedLimit,
          onChanged: _saving ? null : (next) => _save(value.copyWith(showSpeedLimit: next))),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Egen hastighet'),
          subtitle: const Text('GPS-hastighet på mobilen'), value: value.showSpeed,
          onChanged: _saving ? null : (next) => _save(value.copyWith(showSpeed: next))),
        const SizedBox(height: 16),
        Text('Gjelder mobilen. Kartlag, favoritter og fullførte turer styres fra Kartinnstillinger på Kart.',
          style: Theme.of(context).textTheme.bodySmall),
        if (_saving) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ]));
  }
}
