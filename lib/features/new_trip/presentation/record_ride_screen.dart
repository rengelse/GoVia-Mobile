import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_scope.dart';
import '../../../core/display/screen_runtime.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class RecordRideScreen extends StatefulWidget {
  const RecordRideScreen({super.key});

  @override
  State<RecordRideScreen> createState() => _RecordRideScreenState();
}

class _RecordRideScreenState extends State<RecordRideScreen> {
  bool recording = false;
  bool busy = true;
  StreamSubscription<Position>? previewSubscription;
  Timer? timer;
  int previewPoints = 0;
  DateTime? started;
  List<GeoPoint> previewTrack = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreRecordingState());
  }

  Future<void> _restoreRecordingState() async {
    final appState = AppScope.of(context);
    final active = await appState.isRideRecording();
    if (!mounted) return;
    setState(() {
      recording = active;
      busy = false;
      if (active) started = DateTime.now();
    });
    if (active) _startPreview();
  }

  @override
  void dispose() {
    timer?.cancel();
    previewSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied && permission != LocationPermission.deniedForever;
  }

  void _startPreview() {
    previewSubscription?.cancel();
    previewSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((position) {
      if (!mounted) return;
      final point = GeoPoint(lat: position.latitude, lon: position.longitude);
      final last = previewTrack.isEmpty ? null : previewTrack.last;
      final shouldExtendTrack = last == null ||
          Geolocator.distanceBetween(last.lat, last.lon, point.lat, point.lon) >= 25;
      setState(() {
        previewPoints++;
        if (shouldExtendTrack) previewTrack = [...previewTrack, point];
      });
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && recording) setState(() {});
    });
  }

  Future<void> _start() async {
    final appState = AppScope.of(context);
    if (!await _ensureLocationPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posisjonstillatelse kreves for opptak.')),
        );
      }
      return;
    }
    setState(() => busy = true);
    try {
      await appState.startRideRecording();
      if (!mounted) return;
      setState(() {
        recording = true;
        busy = false;
        started = DateTime.now();
        previewPoints = 0;
        previewTrack = const [];
      });
      _startPreview();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke starte opptak: $e')));
    }
  }

  Future<void> _stop() async {
    final appState = AppScope.of(context);
    setState(() => busy = true);
    await previewSubscription?.cancel();
    previewSubscription = null;
    timer?.cancel();
    timer = null;
    try {
      final imported = await appState.stopRideRecordingAndImport();
      if (!mounted) return;
      setState(() {
        recording = false;
        busy = false;
        started = null;
        previewTrack = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(imported > 0 ? 'Turen er lagret i historikken.' : 'Opptaket ble stoppet, men manglet nok GPS-punkter til å lagres.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke lagre opptaket: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => ScreenActivity(
        active: recording,
        child: GoViaScreen(
          title: 'Ta opp tur',
          child: Column(
            children: [
              if (recording) ...[
                RouteMapCard(
                  height: 300,
                  points: previewTrack,
                  connectPoints: previewTrack.length > 1,
                  label: previewTrack.isEmpty ? 'Venter på GPS' : 'Live opptak',
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kartet viser en live forhåndsvisning mens denne skjermen er åpen. Selve opptaket fortsetter i bakgrunnen.',
                    style: TextStyle(color: GoViaColors.muted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.radio_button_checked, color: GoViaColors.orange),
                    title: const Text('Klar til opptak', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Kartet vises når opptaket starter og GPS-sporet begynner å bygges.'),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  MetricCard(label: 'GPS-oppdateringer', value: '$previewPoints', icon: Icons.gps_fixed, color: GoViaColors.orange),
                  const SizedBox(width: 10),
                  MetricCard(label: 'Tid', value: started == null ? '0:00' : _elapsed(), icon: Icons.timer_outlined),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: recording ? GoViaColors.red : GoViaColors.orange),
                onPressed: busy ? null : (recording ? _stop : _start),
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(recording ? Icons.stop : Icons.radio_button_checked),
                label: Text(recording ? 'Avslutt og lagre' : 'Start opptak'),
              ),
              const SizedBox(height: 14),
              Text(
                recording
                    ? 'Opptaket kjøres som en Android bakgrunnstjeneste og fortsetter når appen ikke er i forgrunnen.'
                    : 'Et ferdig opptak lagres lokalt som en fullført tur og vises i historikken.',
                style: const TextStyle(color: GoViaColors.muted),
              ),
            ],
          ),
        ),
      );

  String _elapsed() {
    final d = DateTime.now().difference(started!);
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
