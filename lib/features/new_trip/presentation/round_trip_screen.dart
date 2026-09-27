import 'package:flutter/material.dart';

import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/route_profile_picker.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';
import '../../../domain/transport_profiles.dart';

class RoundTripScreen extends StatefulWidget {
  const RoundTripScreen({super.key});

  @override
  State<RoundTripScreen> createState() => _RoundTripScreenState();
}

class _RoundTripScreenState extends State<RoundTripScreen> {
  double km = 180;
  String direction = 'Fri';
  StageTransport transport = StageTransport.motorcycle;
  String profile = defaultProfileForTransport(StageTransport.motorcycle);

  @override
  Widget build(BuildContext context) => GoViaScreen(
        title: 'Opprett rundtur',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RouteMapCard(height: 250, label: 'Rundtur'),
            const SizedBox(height: 18),
            DropdownButtonFormField<StageTransport>(
              initialValue: transport,
              decoration: const InputDecoration(labelText: 'Transporttype'),
              items: [for (final value in StageTransport.values.where((value) => value != StageTransport.ferry && value != StageTransport.train)) DropdownMenuItem(value: value, child: Text(transportLabel(value)))],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  transport = value;
                  profile = defaultProfileForTransport(value);
                });
              },
            ),
            const SizedBox(height: 14),
            Text('Ønsket lengde: ${km.round()} km', style: const TextStyle(fontWeight: FontWeight.w800)),
            Slider(value: km, min: 10, max: 600, divisions: 59, label: '${km.round()} km', onChanged: (value) => setState(() => km = value)),
            DropdownButtonFormField<String>(
              initialValue: direction,
              decoration: const InputDecoration(labelText: 'Retning'),
              items: const ['Fri', 'Nord', 'Sør', 'Øst', 'Vest', 'Tilfeldig'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => direction = value ?? direction),
            ),
            const SizedBox(height: 10),
            RouteProfilePicker(transport: transport, value: profile, onChanged: (value) => setState(() => profile = value)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Backendkontrakt mangler'),
                    content: Text('Roundtrip-generatoren er transportklar for ${transportLabel(transport)}, men GoVia-serveren har ennå ikke et roundtrip-endpoint. Appen lager derfor ikke oppdiktede ruter.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
                  ),
                );
              },
              icon: const Icon(Icons.loop),
              label: const Text('Generer rundtur'),
            ),
            const SizedBox(height: 12),
            const Text('Når serverkontrakten er implementert skal GoVia generere 1–3 kandidater med transportspesifikke profiler.', style: TextStyle(color: GoViaColors.muted)),
          ],
        ),
      );
}
