import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, this.stage}); final Stage? stage;
  @override State<NavigationScreen> createState() => _NavigationScreenState();
}
class _NavigationScreenState extends State<NavigationScreen> {
  bool muted = false; bool running = true; int meters = 2400; Timer? timer;
  @override void initState() { super.initState(); timer = Timer.periodic(const Duration(seconds: 2), (_) { if (mounted && running && meters > 100) setState(() => meters -= 70); }); }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final s = widget.stage;
    RouteCandidate? official;
    if (s != null) {
      for (final candidate in s.routeCandidates) {
        if (candidate.id == s.officialRouteId || (official == null && candidate.official)) official = candidate;
      }
    }
    return Scaffold(backgroundColor: GoViaColors.bg, body: SafeArea(child: Column(children: [
      Container(padding: const EdgeInsets.fromLTRB(18,12,18,16), color: GoViaColors.panel, child: Row(children: [const Icon(Icons.turn_right_rounded, color: GoViaColors.orange, size: 52), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${(meters/1000).toStringAsFixed(1)} km', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const Text('Ta til høyre · E39', style: TextStyle(color: GoViaColors.muted, fontSize: 16))])), IconButton(onPressed: () => setState(() => muted = !muted), icon: Icon(muted ? Icons.volume_off : Icons.volume_up))])),
      Expanded(child: Padding(padding: const EdgeInsets.all(12), child: RouteMapCard(height: 420, points: official?.geometry ?? const [], label: 'Navigerer', showRiders: true))),
      Container(padding: const EdgeInsets.fromLTRB(18,14,18,16), decoration: const BoxDecoration(color: GoViaColors.panel, border: Border(top: BorderSide(color: GoViaColors.border))), child: Column(children: [
        Row(children: [MetricCard(label: 'Igjen', value: '183 km', icon: Icons.route, color: GoViaColors.orange), const SizedBox(width: 10), MetricCard(label: 'ETA', value: '17:42', icon: Icons.schedule), const SizedBox(width: 10), MetricCard(label: 'Neste stopp', value: '34 km', icon: Icons.local_gas_station_outlined, color: GoViaColors.green)]),
        const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => running = !running), icon: Icon(running ? Icons.pause : Icons.play_arrow), label: Text(running ? 'Pause' : 'Fortsett'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: GoViaColors.red), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.stop), label: const Text('Stopp')))])
      ])),
    ])));
  }
}
