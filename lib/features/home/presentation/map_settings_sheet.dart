import 'package:flutter/material.dart';
import '../domain/map_home_preferences.dart';

class MapSettingsSheet extends StatefulWidget {
  const MapSettingsSheet({super.key, required this.preferences, required this.onChanged});
  final MapHomePreferences preferences;
  final ValueChanged<MapHomePreferences> onChanged;
  @override
  State<MapSettingsSheet> createState() => _MapSettingsSheetState();
}

class _MapSettingsSheetState extends State<MapSettingsSheet> {
  late MapHomePreferences _preferences;
  @override
  void initState() { super.initState(); _preferences = widget.preferences; }
  void _set(MapHomePreferences value) {
    setState(() => _preferences = value);
    widget.onChanged(value);
  }
  @override
  Widget build(BuildContext context) => SafeArea(child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('Kartinnstillinger', style: Theme.of(context).textTheme.titleLarge)),
        IconButton(tooltip: 'Lukk', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'standard', label: Text('Standard')),
          ButtonSegment(value: 'terrain', label: Text('Terreng')),
          ButtonSegment(value: 'satellite', label: Text('Satellitt'))],
        selected: {_preferences.mapType}, showSelectedIcon: false,
        onSelectionChanged: (values) => _set(_preferences.copyWith(mapType: values.single)),
      )),
      const SizedBox(height: 8),
      Text(_preferences.mapType == 'standard' ? 'Kartet følger appens lys/mørk-tema.' :
        _preferences.mapType == 'terrain' ? 'Topografisk kart med høydekurver.' : 'Satellitt- og flyfoto.',
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 20),
      Text('Vis på kartet', style: Theme.of(context).textTheme.titleMedium),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktiv tur'),
        subtitle: const Text('Oransje rute'), value: _preferences.activeTrip,
        onChanged: (value) => _set(_preferences.copyWith(activeTrip: value))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Publiserte turer'),
        subtitle: const Text('Blå ruter · følger transport og kategori'), value: _preferences.publishedRoutes,
        onChanged: (value) => _set(_preferences.copyWith(publishedRoutes: value))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Favoritter'),
        subtitle: const Text('Grønne ruter · dine lagrede turer'), value: _preferences.favorites,
        onChanged: (value) => _set(_preferences.copyWith(favorites: value))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Fullførte turer'),
        subtitle: const Text('Lilla ruter · følger valgt transport'), value: _preferences.completedTrips,
        onChanged: (value) => _set(_preferences.copyWith(completedTrips: value))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Steder'),
        subtitle: const Text('Steder for kategorien valgt under søkefeltet'), value: _preferences.places,
        onChanged: (value) => _set(_preferences.copyWith(places: value))),
      const Divider(),
      Text('Turkortene beholdes under søket. Valgene her styrer kartvisningen.', style: Theme.of(context).textTheme.bodySmall),
    ]),
  ));
}
