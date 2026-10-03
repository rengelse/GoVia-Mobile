import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../app/app_scope.dart';
import '../../../domain/models.dart';
import '../data/offline_map_controller.dart';
import '../domain/offline_area.dart';
import 'offline_area_picker.dart';
import 'offline_catalog_screen.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});
  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try { await action(); }
    catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
  Future<void> _trip(BuildContext context, OfflineMapController controller) async {
    final trip = AppScope.of(context).activeTrip;
    if (trip == null) return;
    await _run(context, () async {
      final area = await configureOfflineArea(context, OfflineArea.forTrip(trip));
      if (area != null) await controller.download(area);
    });
  }
  Future<void> _area(BuildContext context, OfflineMapController controller) async {
    final geometry = AppScope.of(context).activeTrip == null ? const <GeoPoint>[] : OfflineArea.officialGeometry(AppScope.of(context).activeTrip!);
    final point = geometry.isEmpty ? null : LatLng(geometry.first.lat, geometry.first.lon);
    final area = await Navigator.of(context).push<OfflineArea>(MaterialPageRoute(builder: (_) => OfflineAreaPicker(initialPoint: point)));
    if (context.mounted && area != null) await _run(context, () => controller.download(area));
  }
  Future<void> _delete(BuildContext context, OfflineMapController controller, OfflineMapEntry entry) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Slett nedlastet kart?'), content: Text('${entry.name} fjernes fra denne enheten. Turen din slettes ikke.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Avbryt')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Slett kart'))]));
    if (confirmed == true && context.mounted) await _run(context, () => controller.delete(entry));
  }
  @override
  Widget build(BuildContext context) {
    final controller = OfflineMapScope.of(context);
    final trip = AppScope.of(context).activeTrip;
    return Scaffold(appBar: AppBar(title: const Text('Offlinekart'), actions: [
      IconButton(tooltip: 'Oppdater oversikt', onPressed: () => controller.refresh(), icon: const Icon(Icons.refresh)),
    ]), body: RefreshIndicator(onRefresh: controller.refresh, child: ListView(
      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Last ned kun over Wi-Fi'),
          subtitle: Text(controller.wifi ? 'Wi-Fi er tilkoblet' : 'Wi-Fi er ikke tilkoblet'), value: controller.onlyWifi,
          onChanged: (value) => _run(context, () => controller.setOnlyWifi(value))),
        Text('Hold appen åpen under nedlasting. Arbeidet pauses når appen går i bakgrunnen.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: controller.busy ? null : () async {
          final area = await Navigator.of(context).push<OfflineArea>(MaterialPageRoute(builder: (_) => const OfflineCatalogScreen()));
          if (context.mounted && area != null) { await _run(context, () => controller.download(area)); }
        }, icon: const Icon(Icons.public), label: const Text('Velg land eller region')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: controller.busy ? null : () => _area(context, controller),
          icon: const Icon(Icons.map_outlined), label: const Text('Velg område på kartet')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: controller.busy || trip == null ? null : () => _trip(context, controller),
          icon: const Icon(Icons.route_outlined), label: Text(trip == null ? 'Velg en tur for å laste ned kart' : 'Last ned kart for ${trip.name}')),
        if (controller.busy) ...[
          const SizedBox(height: 12),
          Text('${controller.paused ? 'Pauset' : 'Laster ned'} · ${controller.activeName ?? 'kartområde'}'),
          Wrap(spacing: 8, children: [
            if (!controller.paused) TextButton.icon(onPressed: () => _run(context, controller.pause), icon: const Icon(Icons.pause), label: const Text('Pause')),
            TextButton(onPressed: () => _run(context, controller.stop), child: const Text('Stopp · behold delvis kart')),
          ]),
        ],
        if (controller.message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(controller.message!)),
        const Divider(height: 32),
        Text('Nedlastede kart', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (controller.loading) const LinearProgressIndicator(),
        if (!controller.loading && controller.entries.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('Ingen kart er lastet ned. Velg et område eller last ned kart for en tur.')),
        for (final entry in controller.entries) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${entry.region.definition.mapStyleUrl == OfflineMapController.darkStyle ? 'Mørk' : 'Lys'} standardkart · zoom ${entry.region.definition.minZoom.toInt()}–${entry.region.definition.maxZoom.toInt()}'),
            Text(entry.status == null ? 'Status er utilgjengelig' : entry.ready ? 'Tilgjengelig offline' : 'Delvis nedlastet · ${(entry.progress * 100).round()} %'),
            Text(entry.status == null ? 'Størrelse er ukjent' : '${(entry.bytes / 1024 / 1024).toStringAsFixed(1)} MB ressurser'),
            if (!entry.ready && entry.status != null) Padding(padding: const EdgeInsets.only(top: 8), child: LinearProgressIndicator(value: entry.progress)),
            Wrap(spacing: 8, children: [
              if (!entry.ready) TextButton.icon(onPressed: controller.busy && controller.activeId != entry.region.id ? null
                : () => _run(context, () => controller.continueDownload(entry)), icon: const Icon(Icons.download_outlined), label: const Text('Fortsett')),
              if (entry.ready) TextButton.icon(onPressed: controller.busy ? null : () => _run(context, () => controller.update(entry)),
                icon: const Icon(Icons.refresh), label: const Text('Kontroller oppdateringer')),
              TextButton.icon(onPressed: controller.busy ? null : () => _delete(context, controller, entry), icon: const Icon(Icons.delete_outline), label: const Text('Slett')),
            ]),
          ]))),
        const SizedBox(height: 18),
        Text('Kartfliser kan deles mellom områdene, så størrelsene kan ikke summeres til brukt lagringsplass. Nedlastede kart brukes automatisk innenfor området og zoomnivået. Søk og ny ruteberegning krever nett. Terreng og satellitt inngår ikke i disse pakkene.',
          style: Theme.of(context).textTheme.bodySmall),
      ])));
  }
}
