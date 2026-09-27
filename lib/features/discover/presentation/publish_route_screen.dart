import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../domain/models.dart';

class PublishRouteScreen extends StatefulWidget {
  const PublishRouteScreen({super.key, this.stage});
  final Stage? stage;

  @override
  State<PublishRouteScreen> createState() => _PublishRouteScreenState();
}

class _PublishRouteScreenState extends State<PublishRouteScreen> {
  late final TextEditingController title;
  final description = TextEditingController();
  final tags = TextEditingController();
  final picker = ImagePicker();
  final List<XFile> photos = [];
  bool publishing = false;

  @override
  void initState() {
    super.initState();
    final stage = widget.stage;
    title = TextEditingController(text: stage == null ? '' : '${stage.start} → ${stage.end}');
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final selected = await picker.pickMultiImage(imageQuality: 88, limit: 12);
    if (!mounted || selected.isEmpty) return;
    setState(() {
      for (final photo in selected) {
        if (photos.length >= 12) break;
        if (!photos.any((item) => item.path == photo.path)) photos.add(photo);
      }
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

  Future<void> _publish() async {
    final stage = widget.stage;
    if (stage == null || title.text.trim().isEmpty || publishing) return;
    setState(() => publishing = true);
    try {
      final state = AppScope.of(context);
      final route = await state.publishStage(
        stage: stage,
        title: title.text,
        description: description.text,
        tags: tags.text.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList(growable: false),
      );
      final position = photos.isEmpty ? null : await _optionalPosition();
      for (var index = 0; index < photos.length; index++) {
        final photo = photos[index];
        final bytes = await photo.readAsBytes();
        final extension = _extension(photo.name);
        await state.uploadPublishedRoutePhoto(
          route: route,
          bytes: bytes,
          extension: extension,
          contentType: _contentType(extension),
          lat: position?.latitude,
          lon: position?.longitude,
          position: index,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(photos.isEmpty ? 'Ruten er publisert i Oppdag.' : 'Ruten og ${photos.length} bilde${photos.length == 1 ? '' : 'r'} er publisert.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publisering feilet: $error')));
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    return Scaffold(
      appBar: AppBar(title: const Text('Publiser rute')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Del en kjørbar rute med GoVia-fellesskapet. Den publiserte ruta er et snapshot og endrer ikke originalturen.', style: TextStyle(color: GoViaColors.muted)),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Tittel')),
          const SizedBox(height: 10),
          TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Beskrivelse')),
          const SizedBox(height: 10),
          TextField(controller: tags, decoration: const InputDecoration(labelText: 'Tags', hintText: 'kyst, fjell, familie, utsikt')),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.route_outlined),
            title: const Text('Transporttype'),
            subtitle: Text(stage == null ? 'Ingen rute valgt' : transportLabel(stage.transport)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Bilder (${photos.length}/12)', style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(onPressed: publishing || photos.length >= 12 ? null : _pickPhotos, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Legg til')),
            ],
          ),
          if (photos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Legg til bilder fra turen. Når posisjonstilgang er tilgjengelig lagres også omtrentlig posisjon sammen med bildet.', style: TextStyle(color: GoViaColors.muted)),
              ),
            )
          else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(photos[index].path), width: 116, height: 116, fit: BoxFit.cover)),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: publishing ? null : () => setState(() => photos.removeAt(index)),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: stage == null || publishing ? null : _publish,
            icon: publishing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.public),
            label: Text(publishing ? 'Publiserer…' : 'Publiser'),
          ),
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
