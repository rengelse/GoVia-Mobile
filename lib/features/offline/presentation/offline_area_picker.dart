import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../domain/offline_area.dart';
import '../data/offline_map_controller.dart';

class OfflineAreaPicker extends StatefulWidget {
  const OfflineAreaPicker({super.key, this.initialPoint});
  final LatLng? initialPoint;
  @override
  State<OfflineAreaPicker> createState() => _OfflineAreaPickerState();
}

class _OfflineAreaPickerState extends State<OfflineAreaPicker> {
  MapLibreMapController? _map;
  bool _ready = false;
  bool _selecting = false;
  Future<void> _select() async {
    if (_map == null || _selecting) return;
    setState(() => _selecting = true);
    try {
      final bounds = await _map!.getVisibleRegion();
      if (!mounted) return;
      final area = await configureOfflineArea(context, OfflineArea(name: 'Kartområde',
        south: bounds.southwest.latitude.clamp(-85.0, 85.0).toDouble(), west: bounds.southwest.longitude,
        north: bounds.northeast.latitude.clamp(-85.0, 85.0).toDouble(), east: bounds.northeast.longitude));
      if (mounted && area != null) Navigator.pop(context, area);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunne ikke velge området. Prøv igjen.')));
    } finally { if (mounted) setState(() => _selecting = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Velg kartområde')),
    body: Stack(children: [
      MapLibreMap(styleString: Theme.of(context).brightness == Brightness.dark ? OfflineMapController.darkStyle : OfflineMapController.lightStyle,
        initialCameraPosition: CameraPosition(target: widget.initialPoint ?? const LatLng(60.39, 5.32), zoom: 10),
        onMapCreated: (controller) => _map = controller,
        onStyleLoadedCallback: () { if (mounted) setState(() => _ready = true); }),
      Positioned(left: 16, right: 16, top: 16, child: Card(child: Padding(padding: const EdgeInsets.all(12),
        child: Text('Flytt og zoom kartet. Det synlige området lastes ned.', style: Theme.of(context).textTheme.bodyMedium)))),
      Positioned(left: 16, right: 16, bottom: 24, child: SafeArea(child: FilledButton.icon(
        onPressed: _ready && !_selecting ? _select : null, icon: const Icon(Icons.download_outlined), label: const Text('Velg dette området')))),
    ]));
}

Future<OfflineArea?> configureOfflineArea(BuildContext context, OfflineArea initial) async {
  final name = TextEditingController(text: initial.name);
  var zoom = initial.maxZoom;
  final selected = await showDialog<OfflineArea>(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) {
    final area = OfflineArea(name: name.text, south: initial.south, west: initial.west, north: initial.north, east: initial.east,
      tripId: initial.tripId, maxZoom: zoom);
    return AlertDialog(title: const Text('Last ned kart'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Navn på området')),
      const SizedBox(height: 12),
      DropdownButtonFormField<double>(initialValue: zoom, decoration: const InputDecoration(labelText: 'Detaljnivå · maks zoom'),
        items: [for (final z in {5.0, 10.0, 11.0, 13.0, 15.0, initial.maxZoom}.toList()..sort()) DropdownMenuItem(value: z, child: Text('Zoom ${z.toInt()}'))],
        onChanged: (value) { if (value != null) setState(() => zoom = value); }),
      const SizedBox(height: 12),
      Text(area.valid && area.estimatedTiles <= OfflineArea.maxTiles
        ? 'Omtrent ${area.estimatedTiles} kartfliser per stil. Lys og mørk stil inkluderes. Endelig størrelse vises under nedlasting.'
        : 'Området er for stort eller ugyldig. Velg lavere detaljnivå eller et mindre kartområde.'),
      const SizedBox(height: 8), const Text('Dette laster ned kart. Søk og ny ruteberegning krever fortsatt nett.'),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Avbryt')),
      FilledButton(onPressed: area.valid && area.estimatedTiles <= OfflineArea.maxTiles ? () => Navigator.pop(context, area) : null, child: const Text('Last ned'))]);
  }));
  // Let the dialog transition release its TextField before disposing the controller.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  return selected;
}
