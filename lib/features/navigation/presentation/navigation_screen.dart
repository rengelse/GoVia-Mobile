import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, this.stage});
  final Stage? stage;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Position>? _positionSub;
  RouteCandidate? _official;
  Position? _position;
  int _maneuverIndex = 0;
  int? _lastSpokenBucket;
  String? _positionError;
  bool _muted = false;
  bool _running = true;
  bool _ttsReady = false;
  bool _guidanceRequested = false;

  @override
  void initState() {
    super.initState();
    _official = _findOfficial(widget.stage);
    unawaited(_configureTts());
    unawaited(_startLocation());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_guidanceRequested) {
      _guidanceRequested = true;
      unawaited(_ensureGuidance());
    }
  }

  Future<void> _ensureGuidance() async {
    final route = _official;
    if (route == null || route.maneuvers.isNotEmpty || route.geometry.length < 2) return;
    try {
      final response = await AppScope.of(context).api.postJson('/api/v1/map/guidance', {
        'geometry': [for (final point in route.geometry) [point.lon, point.lat]],
        'distance': route.distanceMeters,
        'duration': route.durationSeconds,
        'mode': widget.stage?.transport.name ?? 'driving',
      });
      final data = response['data'];
      if (data is! Map) return;
      final maneuvers = (data['maneuvers'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => NavigationManeuver.fromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
      if (!mounted || maneuvers.isEmpty) return;
      setState(() {
        _official = route.copyWith(
          maneuvers: maneuvers,
          guidanceSource: data['guidanceSource']?.toString() ?? 'geometry',
        );
      });
    } catch (_) {
      // Navigation remains usable as a route map even if guidance enrichment is unavailable.
    }
  }

  RouteCandidate? _findOfficial(Stage? stage) {
    if (stage == null) return null;
    RouteCandidate? fallback;
    for (final candidate in stage.routeCandidates) {
      if (candidate.id == stage.officialRouteId) return candidate;
      if (fallback == null && candidate.official) fallback = candidate;
    }
    return fallback ?? stage.routeCandidates.firstOrNull;
  }

  Future<void> _configureTts() async {
    try {
      final nb = await _tts.isLanguageAvailable('nb-NO');
      await _tts.setLanguage(nb == true ? 'nb-NO' : 'no-NO');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {
      if (mounted) setState(() => _ttsReady = false);
    }
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _positionError = 'Posisjonstjenester er slått av.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _positionError = 'Posisjonstilgang kreves for navigasjon.');
        return;
      }
      const settings = LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5);
      _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        _onPosition,
        onError: (Object error) {
          if (mounted) setState(() => _positionError = '$error');
        },
      );
    } catch (error) {
      if (mounted) setState(() => _positionError = '$error');
    }
  }

  void _onPosition(Position position) {
    if (!_running) return;
    final firstFix = _position == null;
    _position = position;
    if (firstFix) _snapManeuverIndex(position);
    _advanceManeuverIfNeeded();
    unawaited(_announceIfNeeded());
    if (mounted) setState(() {});
  }

  List<NavigationManeuver> get _maneuvers => _official?.maneuvers ?? const [];

  void _snapManeuverIndex(Position position) {
    if (_maneuvers.isEmpty) return;
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < _maneuvers.length; i++) {
      final maneuver = _maneuvers[i];
      final distance = Geolocator.distanceBetween(position.latitude, position.longitude, maneuver.location.lat, maneuver.location.lon);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestDistance <= 1200) _maneuverIndex = bestIndex;
  }


  NavigationManeuver? get _currentManeuver {
    if (_maneuvers.isEmpty) return null;
    final index = _maneuverIndex.clamp(0, _maneuvers.length - 1).toInt();
    return _maneuvers[index];
  }

  double? get _distanceToManeuver {
    final position = _position;
    final maneuver = _currentManeuver;
    if (position == null || maneuver == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      maneuver.location.lat,
      maneuver.location.lon,
    );
  }

  void _advanceManeuverIfNeeded() {
    if (_position == null || _maneuvers.isEmpty) return;
    while (_maneuverIndex < _maneuvers.length - 1) {
      final maneuver = _maneuvers[_maneuverIndex];
      final distance = Geolocator.distanceBetween(
        _position!.latitude,
        _position!.longitude,
        maneuver.location.lat,
        maneuver.location.lon,
      );
      if (distance > 32) break;
      _maneuverIndex += 1;
      _lastSpokenBucket = null;
    }
  }

  int? _announcementBucket(double meters) {
    if (meters <= 55) return 0;
    if (meters <= 220) return 1;
    if (meters <= 650) return 2;
    return null;
  }

  Future<void> _announceIfNeeded() async {
    if (_muted || !_ttsReady || !_running) return;
    final maneuver = _currentManeuver;
    final meters = _distanceToManeuver;
    if (maneuver == null || meters == null) return;
    final bucket = _announcementBucket(meters);
    if (bucket == null || bucket == _lastSpokenBucket) return;
    _lastSpokenBucket = bucket;
    final instruction = maneuver.instruction.trim().isEmpty ? 'Fortsett' : maneuver.instruction.trim();
    final spoken = switch (bucket) {
      2 => 'Om ${_roundedDistance(meters)}, $instruction',
      1 => 'Om ${_roundedDistance(meters)}, $instruction',
      _ => instruction,
    };
    await _tts.stop();
    await _tts.speak(spoken);
  }

  String _roundedDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(meters >= 5000 ? 0 : 1)} kilometer';
    final rounded = meters >= 300 ? (meters / 100).round() * 100 : meters >= 100 ? (meters / 50).round() * 50 : (meters / 10).round() * 10;
    return '$rounded meter';
  }

  String _distanceLabel(double? meters) {
    if (meters == null) return 'Venter på GPS';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  IconData _maneuverIcon(NavigationManeuver? maneuver) {
    final modifier = maneuver?.modifier ?? '';
    final type = maneuver?.type ?? '';
    if (type.contains('roundabout') || type == 'rotary') return Icons.roundabout_right_rounded;
    if (type == 'arrive') return Icons.flag_rounded;
    if (modifier.contains('left')) return Icons.turn_left_rounded;
    if (modifier.contains('right')) return Icons.turn_right_rounded;
    if (modifier == 'uturn') return Icons.u_turn_left_rounded;
    return Icons.straight_rounded;
  }

  int get _remainingMeters {
    final route = _official;
    final maneuver = _currentManeuver;
    if (route == null) return 0;
    if (maneuver == null) return route.distanceMeters;
    return (route.distanceMeters - maneuver.distanceFromStartMeters).clamp(0, route.distanceMeters).toInt();
  }

  String get _remainingDuration {
    final route = _official;
    if (route == null || route.distanceMeters <= 0) return '—';
    final seconds = (route.durationSeconds * (_remainingMeters / route.distanceMeters)).round();
    final minutes = (seconds / 60).round();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}t ${m}m' : '${m}m';
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    if (_muted) await _tts.stop();
    _lastSpokenBucket = null;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = _official;
    final maneuver = _currentManeuver;
    final distance = _distanceToManeuver;
    final guidanceAvailable = route != null && route.maneuvers.isNotEmpty;
    final derivedGuidance = route?.guidanceSource == 'geometry';

    return Scaffold(
      backgroundColor: GoViaColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              color: GoViaColors.panel,
              child: Row(
                children: [
                  Icon(_maneuverIcon(maneuver), color: GoViaColors.orange, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_distanceLabel(distance), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                        Text(
                          maneuver?.instruction ?? (guidanceAvailable ? 'Venter på posisjon' : 'Manøverdata mangler for denne ruta'),
                          style: const TextStyle(color: GoViaColors.muted, fontSize: 16),
                        ),
                        if (derivedGuidance)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Basisveiledning fra rutegeometri', style: TextStyle(color: GoViaColors.muted, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _muted ? 'Slå på stemme' : 'Demp stemme',
                    onPressed: guidanceAvailable ? _toggleMute : null,
                    icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                  ),
                ],
              ),
            ),
            if (_positionError != null)
              MaterialBanner(
                content: Text(_positionError!),
                actions: [TextButton(onPressed: () => unawaited(_startLocation()), child: const Text('Prøv igjen'))],
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: RouteMapCard(
                  key: ValueKey('navigation-${route?.id}-${route?.geometry.length ?? 0}'),
                  height: 420,
                  points: route?.geometry ?? const [],
                  label: 'Navigerer',
                  showRiders: true,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: const BoxDecoration(color: GoViaColors.panel, border: Border(top: BorderSide(color: GoViaColors.border))),
              child: Column(
                children: [
                  Row(
                    children: [
                      MetricCard(label: 'Igjen', value: _remainingMeters >= 1000 ? '${(_remainingMeters / 1000).round()} km' : '$_remainingMeters m', icon: Icons.route, color: GoViaColors.orange),
                      const SizedBox(width: 10),
                      MetricCard(label: 'Tid igjen', value: _remainingDuration, icon: Icons.schedule),
                      const SizedBox(width: 10),
                      MetricCard(label: 'Manøver', value: guidanceAvailable ? '${_maneuverIndex + 1}/${_maneuvers.length}' : '—', icon: Icons.alt_route, color: GoViaColors.green),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _running = !_running),
                          icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                          label: Text(_running ? 'Pause' : 'Fortsett'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: GoViaColors.red),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stopp'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
