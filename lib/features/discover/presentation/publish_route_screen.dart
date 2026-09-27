import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class PublishRouteArgs {
  const PublishRouteArgs({this.stage, this.existingRoute});
  final Stage? stage;
  final PublishedRoute? existingRoute;
}

class PublishRouteScreen extends StatefulWidget {
  const PublishRouteScreen({super.key, this.args});
  final PublishRouteArgs? args;

  @override
  State<PublishRouteScreen> createState() => _PublishRouteScreenState();
}

class _PublishRouteScreenState extends State<PublishRouteScreen> {
  final description = TextEditingController();
  final tags = TextEditingController();
  final picker = ImagePicker();
  final List<XFile> newPhotos = [];
  final Set<String> removedRemotePhotoIds = <String>{};
  late final TextEditingController title;

  Stage? selectedStage;
  Trip? sourceTrip;
  String visibility = 'public';
  String? coverKey;
  bool preview = false;
  bool saving = false;

  PublishedRoute? get existing => widget.args?.existingRoute;
  bool get editing => existing != null;

  @override
  void initState() {
    super.initState();
    selectedStage = widget.args?.stage;
    final route = existing;
    title = TextEditingController(text: route?.title ?? (selectedStage == null ? '' : '${selectedStage!.start} → ${selectedStage!.end}'));
    description.text = route?.description ?? '';
    tags.text = route?.tags.join(', ') ?? '';
    visibility = route?.visibility ?? 'public';
    coverKey = route?.photos.isNotEmpty == true ? 'remote:${route!.photos.first.id}' : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (sourceTrip == null && selectedStage != null) {
      sourceTrip = AppScope.of(context).trips.where((trip) => trip.stages.any((stage) => stage.id == selectedStage!.id)).firstOrNull;
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    tags.dispose();
    super.dispose();
  }

  List<_StageSource> _sources() {
    final state = AppScope.of(context);
    final rows = <_StageSource>[];
    for (final trip in state.trips) {
      if (trip.status == TripStatus.archived) continue;
      for (final stage in trip.stages) {
        if (stage.transport == StageTransport.ferry) continue;
        final official = _official(stage);
        if (official == null || official.geometry.length < 2) continue;
        rows.add(_StageSource(trip: trip, stage: stage));
      }
    }
    rows.sort((a, b) {
      final date = b.trip.startDate.compareTo(a.trip.startDate);
      if (date != 0) return date;
      final day = a.stage.day.compareTo(b.stage.day);
      return day != 0 ? day : a.stage.order.compareTo(b.stage.order);
    });
    return rows;
  }

  RouteCandidate? _official(Stage stage) {
    RouteCandidate? official;
    for (final candidate in stage.routeCandidates) {
      if (candidate.id == stage.officialRouteId || (official == null && candidate.official)) official = candidate;
    }
    return official;
  }

  void _invalidatePreview() {
    if (preview) setState(() => preview = false);
  }

  Future<void> _pickPhotos() async {
    final selected = await picker.pickMultiImage(imageQuality: 88, limit: 12);
    if (!mounted || selected.isEmpty) return;
    setState(() {
      for (final photo in selected) {
        if ((existing?.photos.length ?? 0) + newPhotos.length >= 12) break;
        if (!newPhotos.any((item) => item.path == photo.path)) newPhotos.add(photo);
      }
      coverKey ??= newPhotos.isEmpty ? null : 'local:${newPhotos.first.path}';
      preview = false;
    });
  }

  Future<Position?> _optionalPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
    } catch (_) {
      return null;
    }
  }

  List<String> _tags() => tags.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .take(12)
      .toList(growable: false);

  Future<void> _save({required String status}) async {
    final stage = selectedStage;
    if ((!editing && stage == null) || title.text.trim().isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final state = AppScope.of(context);
      PublishedRoute route;
      if (editing) {
        route = await state.updatePublishedRoute(
          route: existing!,
          title: title.text,
          description: description.text,
          tags: _tags(),
          visibility: visibility,
          status: status,
        );
      } else {
        route = await state.publishStage(
          stage: stage!,
          title: title.text,
          description: description.text,
          tags: _tags(),
          visibility: visibility,
          status: status,
          sourceTripId: sourceTrip?.id,
        );
      }

      final position = newPhotos.isEmpty ? null : await _optionalPosition();
      PublishedRoutePhoto? localCover;
      final ordered = [...newPhotos];
      if (coverKey?.startsWith('local:') == true) {
        final path = coverKey!.substring('local:'.length);
        ordered.sort((a, b) => a.path == path ? -1 : b.path == path ? 1 : 0);
      }
      for (var index = 0; index < ordered.length; index++) {
        final photo = ordered[index];
        final extension = _extension(photo.name);
        final uploaded = await state.uploadPublishedRoutePhoto(
          route: route,
          bytes: await photo.readAsBytes(),
          extension: extension,
          contentType: _contentType(extension),
          lat: position?.latitude,
          lon: position?.longitude,
          position: (route.photos.length + index),
        );
        if (coverKey == 'local:${photo.path}') localCover = uploaded;
      }

      if (localCover != null) {
        await state.setPublishedRouteCover(route, localCover);
      } else if (coverKey?.startsWith('remote:') == true) {
        final id = coverKey!.substring('remote:'.length);
        final candidate = route.photos.where((photo) => photo.id == id).firstOrNull ?? existing?.photos.where((photo) => photo.id == id).firstOrNull;
        if (candidate != null) await state.setPublishedRouteCover(route, candidate);
      }

      await state.refreshMyPublishedRoutes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'draft' ? 'Utkastet er lagret.' : editing ? 'Publiseringen er oppdatert.' : 'Ruten er publisert i Oppdag.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke lagre publiseringen: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _removeRemotePhoto(PublishedRoutePhoto photo) async {
    final route = existing;
    if (route == null || saving) return;
    setState(() => saving = true);
    try {
      await AppScope.of(context).removePublishedRoutePhoto(route, photo);
      if (coverKey == 'remote:${photo.id}') coverKey = null;
      removedRemotePhotoIds.add(photo.id);
      if (mounted) setState(() => preview = false);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = selectedStage;
    final route = existing;
    final geometry = route?.geometry ?? (stage == null ? const <GeoPoint>[] : (_official(stage)?.geometry ?? const <GeoPoint>[]));
    final sources = _sources();
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Rediger publisering' : 'Publiser tur')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (preview)
            _previewContent(context, geometry)
          else ...[
            const Text('Den publiserte ruten er et eget snapshot. Endringer her endrer aldri den private GoVia-turen din.', style: TextStyle(color: GoViaColors.muted)),
            const SizedBox(height: 16),
            if (!editing)
              DropdownButtonFormField<String>(
                initialValue: stage == null ? null : '${sourceTrip?.id ?? ''}|${stage.id}',
                decoration: const InputDecoration(labelText: 'Kilde · faktisk GoVia-rute'),
                items: [
                  for (final source in sources)
                    DropdownMenuItem(
                      value: '${source.trip.id}|${source.stage.id}',
                      child: Text('${source.trip.name} · Dag ${source.stage.day}: ${source.stage.start} → ${source.stage.end}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        final source = sources.where((row) => '${row.trip.id}|${row.stage.id}' == value).firstOrNull;
                        if (source == null) return;
                        setState(() {
                          sourceTrip = source.trip;
                          selectedStage = source.stage;
                          if (title.text.trim().isEmpty) title.text = '${source.stage.start} → ${source.stage.end}';
                          preview = false;
                        });
                      },
              )
            else
              _sourceSummary(route!),
            const SizedBox(height: 12),
            TextField(controller: title, onChanged: (_) => _invalidatePreview(), decoration: const InputDecoration(labelText: 'Tittel')),
            const SizedBox(height: 10),
            TextField(controller: description, onChanged: (_) => _invalidatePreview(), maxLines: 4, decoration: const InputDecoration(labelText: 'Beskrivelse')),
            const SizedBox(height: 10),
            TextField(controller: tags, onChanged: (_) => _invalidatePreview(), decoration: const InputDecoration(labelText: 'Egenskaper / tags', hintText: 'kyst, fjell, utsikt, svingete')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: visibility,
              decoration: const InputDecoration(labelText: 'Synlighet'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Offentlig · vises i Oppdag')),
                DropdownMenuItem(value: 'unlisted', child: Text('Skjult lenke · bare med direkte lenke')),
                DropdownMenuItem(value: 'private', child: Text('Privat · bare meg')),
              ],
              onChanged: saving ? null : (value) => setState(() { visibility = value ?? 'public'; preview = false; }),
            ),
            const SizedBox(height: 16),
            if (geometry.isNotEmpty) RouteMapCard(height: 220, points: geometry, label: 'Publiseringssnapshot'),
            const SizedBox(height: 18),
            _photoEditor(route),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving || (!editing && stage == null) || title.text.trim().isEmpty ? null : () => setState(() => preview = true),
              icon: const Icon(Icons.preview_outlined),
              label: const Text('Forhåndsvis før publisering'),
            ),
            if (!editing) ...[
              const SizedBox(height: 10),
              TextButton.icon(onPressed: saving || stage == null ? null : () => _save(status: 'draft'), icon: const Icon(Icons.save_outlined), label: const Text('Lagre som utkast')),
            ],
          ],
        ],
      ),
    );
  }

  Widget _previewContent(BuildContext context, List<GeoPoint> geometry) {
    final remote = (existing?.photos ?? const <PublishedRoutePhoto>[]).where((photo) => !removedRemotePhotoIds.contains(photo.id)).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [IconButton(onPressed: saving ? null : () => setState(() => preview = false), icon: const Icon(Icons.arrow_back)), const Text('Forhåndsvisning', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 8),
        if (geometry.isNotEmpty) RouteMapCard(height: 250, points: geometry, label: transportLabel(selectedStage?.transport ?? existing?.transport ?? StageTransport.car)),
        const SizedBox(height: 16),
        Text(title.text.trim(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(description.text.trim().isEmpty ? 'Ingen beskrivelse.' : description.text.trim(), style: const TextStyle(color: GoViaColors.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final tag in _tags()) StatusPill(tag, color: GoViaColors.blue)]),
        const SizedBox(height: 18),
        if (remote.isNotEmpty || newPhotos.isNotEmpty) ...[
          const SectionTitle('Bilder'),
          SizedBox(
            height: 125,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final photo in remote) Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(photo.url, width: 140, fit: BoxFit.cover))),
                for (final photo in newPhotos) Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(photo.path), width: 140, fit: BoxFit.cover))),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        FilledButton.icon(
          onPressed: saving ? null : () => _save(status: 'published'),
          icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.public),
          label: Text(saving ? 'Lagrer…' : editing ? 'Oppdater publisering' : 'Publiser i Oppdag'),
        ),
      ],
    );
  }

  Widget _sourceSummary(PublishedRoute route) => Card(
        child: ListTile(
          leading: const Icon(Icons.lock_outline, color: GoViaColors.blue),
          title: Text('${route.start} → ${route.end}'),
          subtitle: Text('Kildesnapshot · ${transportLabel(route.transport)} · ${(route.distanceMeters / 1000).round()} km'),
        ),
      );

  Widget _photoEditor(PublishedRoute? route) {
    final remote = (route?.photos ?? const <PublishedRoutePhoto>[]).where((photo) => !removedRemotePhotoIds.contains(photo.id)).toList(growable: false);
    final total = remote.length + newPhotos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Bilder ($total/12)', style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(onPressed: saving || total >= 12 ? null : _pickPhotos, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Legg til')),
          ],
        ),
        if (total == 0)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Legg til et coverbilde og gjerne flere bilder fra turen.', style: TextStyle(color: GoViaColors.muted))))
        else
          SizedBox(
            height: 138,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final photo in remote) _remotePhotoTile(photo),
                for (final photo in newPhotos) _localPhotoTile(photo),
              ],
            ),
          ),
        if (total > 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Trykk på stjernen for å velge coverbilde.', style: TextStyle(color: GoViaColors.muted, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _remotePhotoTile(PublishedRoutePhoto photo) {
    final selected = coverKey == 'remote:${photo.id}';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(photo.url, width: 132, height: 132, fit: BoxFit.cover)),
          Positioned(top: 4, left: 4, child: IconButton.filledTonal(onPressed: saving ? null : () => setState(() { coverKey = 'remote:${photo.id}'; preview = false; }), icon: Icon(selected ? Icons.star : Icons.star_border, color: selected ? GoViaColors.orange : null))),
          Positioned(top: 4, right: 4, child: IconButton.filledTonal(onPressed: saving ? null : () => _removeRemotePhoto(photo), icon: const Icon(Icons.delete_outline, size: 18))),
        ],
      ),
    );
  }

  Widget _localPhotoTile(XFile photo) {
    final selected = coverKey == 'local:${photo.path}';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(photo.path), width: 132, height: 132, fit: BoxFit.cover)),
          Positioned(top: 4, left: 4, child: IconButton.filledTonal(onPressed: saving ? null : () => setState(() { coverKey = 'local:${photo.path}'; preview = false; }), icon: Icon(selected ? Icons.star : Icons.star_border, color: selected ? GoViaColors.orange : null))),
          Positioned(top: 4, right: 4, child: IconButton.filledTonal(onPressed: saving ? null : () => setState(() { newPhotos.remove(photo); if (selected) coverKey = null; preview = false; }), icon: const Icon(Icons.close, size: 18))),
        ],
      ),
    );
  }

  String _extension(String name) {
    final index = name.lastIndexOf('.');
    return index >= 0 ? name.substring(index + 1).toLowerCase() : 'jpg';
  }

  String _contentType(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => 'image/jpeg',
      };
}

class _StageSource {
  const _StageSource({required this.trip, required this.stage});
  final Trip trip;
  final Stage stage;
}
