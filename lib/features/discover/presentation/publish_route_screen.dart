import 'package:flutter/material.dart';

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

  Future<void> _publish() async {
    final stage = widget.stage;
    if (stage == null || title.text.trim().isEmpty) return;
    setState(() => publishing = true);
    try {
      await AppScope.of(context).publishStage(
        stage: stage,
        title: title.text,
        description: description.text,
        tags: tags.text.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList(growable: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruten er publisert i Oppdag.')));
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
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bildeopplasting kommer i neste community-pass. Denne releasen publiserer selve rutesnapshotet, metadata og transporttype.'),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: stage == null || publishing ? null : _publish,
            icon: const Icon(Icons.public),
            label: Text(publishing ? 'Publiserer…' : 'Publiser'),
          ),
        ],
      ),
    );
  }
}
