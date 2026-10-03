import 'package:flutter/material.dart';
import '../domain/offline_catalog.dart';
import 'offline_area_picker.dart';

class OfflineCatalogScreen extends StatefulWidget {
  const OfflineCatalogScreen({super.key});
  @override
  State<OfflineCatalogScreen> createState() => _OfflineCatalogScreenState();
}
class _OfflineCatalogScreenState extends State<OfflineCatalogScreen> {
  late final Future<List<OfflineCatalogCountry>> _catalog = loadOfflineCatalog();
  String? _continent;
  OfflineCatalogCountry? _country;
  String _query = '';
  Future<void> _select(OfflineCatalogArea entry) async {
    final area = entry.area;
    if (!area.valid || area.east - area.west > 180) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Området krysser datolinjen eller kartgrensen. Velg en mindre region eller bruk kartet.')));
      return;
    }
    final selected = await configureOfflineArea(context, area);
    if (mounted && selected != null) { Navigator.pop(context, selected); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_country?.area.name ?? _continent ?? 'Land og regioner'),
      leading: BackButton(onPressed: () {
        if (_country != null) { setState(() { _country = null; _query = ''; }); }
        else if (_continent != null) { setState(() { _continent = null; _query = ''; }); }
        else { Navigator.pop(context); }
      })),
    body: FutureBuilder<List<OfflineCatalogCountry>>(future: _catalog, builder: (context, snapshot) {
      if (snapshot.hasError) { return const Center(child: Text('Kunne ikke lese kartoversikten.')); }
      if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
      final countries = snapshot.data!;
      final query = _query.trim().toLowerCase();
      final continents = countries.map((c) => c.continent).toSet().toList()..sort();
      final matches = countries.where((c) => (_continent == null || c.continent == _continent) &&
        (c.area.name.toLowerCase().contains(query) || c.regions.any((r) => r.name.toLowerCase().contains(query)))).toList();
      return ListView(padding: const EdgeInsets.all(18), children: [
        TextField(key: ValueKey('${_continent ?? ''}/${_country?.area.id ?? ''}'),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Søk etter land eller region'),
          onChanged: (value) => setState(() => _query = value)),
        const SizedBox(height: 12),
        const Text('Kartområdene følger geografiske utsnitt og kan inkludere hav og naboområder. Store områder gir lavere detaljnivå. Velg en region for flere detaljer.'),
        const SizedBox(height: 12),
        if (_country != null) ...[
          if (query.isEmpty) ListTile(title: const Text('Hele landet'), subtitle: Text('Maks zoom ${_country!.area.area.maxZoom.toInt()}'),
            trailing: const Icon(Icons.download_outlined), onTap: () => _select(_country!.area)),
          for (final region in _country!.regions.where((r) => r.name.toLowerCase().contains(query)))
            ListTile(title: Text(region.name), subtitle: Text('Maks zoom ${region.area.maxZoom.toInt()}'),
              trailing: const Icon(Icons.download_outlined), onTap: () => _select(region)),
          if (_country!.regions.isEmpty) const Text('Ingen underregioner i katalogen. Du kan også velge område direkte på kartet.'),
        ] else if (_continent == null && query.isEmpty) ...[
          for (final continent in continents) ListTile(title: Text(continent), trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _continent = continent)),
        ] else ...[
          for (final country in matches) ...[
            ListTile(title: Text(country.area.name), subtitle: Text('${country.regions.length} regioner'),
              trailing: const Icon(Icons.chevron_right), onTap: () => setState(() { _country = country; _query = ''; })),
            if (query.isNotEmpty && !country.area.name.toLowerCase().contains(query))
              for (final region in country.regions.where((r) => r.name.toLowerCase().contains(query)))
                ListTile(title: Text('${country.area.name} · ${region.name}'), trailing: const Icon(Icons.download_outlined), onTap: () => _select(region)),
          ],
          if (matches.isEmpty) const Text('Ingen treff.'),
        ],
      ]);
    }));
}
