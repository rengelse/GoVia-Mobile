import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';
import '../../../domain/transport_profiles.dart';
import 'navigation_map_cockpit.dart';

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
  bool _followCamera = true;
  GeoPoint? _matchedPoint;
  double _offRouteDistanceMeters = 0;
  int _offRouteFixes = 0;
  DateTime? _lastRerouteAt;
  bool _rerouting = false;
  int _arrivalFixes = 0;
  bool _arrived = false;
  bool _arrivalAnnounced = false;

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
      final LocationSettings settings;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'GoVia navigerer',
            notificationText: 'Navigasjonen fortsetter i bakgrunnen.',
            notificationChannelName: 'GoVia navigasjon',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      } else {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        );
      }
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
    _matchedPoint = _matchToRoute(position);
    _offRouteDistanceMeters = _distanceFromRoute(position);
    _updateArrival(position);
    if (!_arrived && _offRouteDistanceMeters > 85) {
      _offRouteFixes += 1;
    } else {
      _offRouteFixes = 0;
    }
    if (firstFix) _snapManeuverIndex(position);
    _advanceManeuverIfNeeded();
    unawaited(_announceIfNeeded());
    unawaited(_rerouteIfNeeded());
    if (mounted) setState(() {});
  }


  GeoPoint? _matchToRoute(Position position) {
    final geometry = _official?.geometry ?? const <GeoPoint>[];
    if (geometry.isEmpty) return null;
    var best = geometry.first;
    var bestDistance = double.infinity;
    final stride = geometry.length > 1200 ? (geometry.length / 1200).ceil() : 1;
    for (var i = 0; i < geometry.length; i += stride) {
      final point = geometry[i];
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.lat,
        point.lon,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }
    return bestDistance <= 140 ? best : null;
  }

  double _distanceFromRoute(Position position) {
    final geometry = _official?.geometry ?? const <GeoPoint>[];
    if (geometry.isEmpty) return 0;
    var bestDistance = double.infinity;
    final stride = geometry.length > 1200 ? (geometry.length / 1200).ceil() : 1;
    for (var i = 0; i < geometry.length; i += stride) {
      final point = geometry[i];
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.lat,
        point.lon,
      );
      if (distance < bestDistance) bestDistance = distance;
    }
    return bestDistance;
  }

  void _updateArrival(Position position) {
    final geometry = _official?.geometry ?? const <GeoPoint>[];
    if (geometry.isEmpty || _arrived) return;
    final destination = geometry.last;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destination.lat,
      destination.lon,
    );
    final speed = position.speed.isFinite ? position.speed.clamp(0, 100).toDouble() : 0.0;
    final credibleArrival = distance <= 25 || (distance <= 55 && speed <= 5);
    if (credibleArrival) {
      _arrivalFixes += 1;
    } else if (distance > 80) {
      _arrivalFixes = 0;
    }
    if (_arrivalFixes >= 3) {
      _arrived = true;
      _offRouteFixes = 0;
      unawaited(_announceArrival());
    }
  }

  Future<void> _announceArrival() async {
    if (_arrivalAnnounced || _muted || !_ttsReady) return;
    _arrivalAnnounced = true;
    await _tts.stop();
    await _tts.speak('Du er fremme.');
  }

  Future<void> _rerouteIfNeeded() async {
    final stage = widget.stage;
    final position = _position;
    final route = _official;
    if (stage == null || position == null || route == null || _arrived || _rerouting || _offRouteFixes < 3) return;
    if (stage.transport == StageTransport.train || stage.transport == StageTransport.ferry) return;
    final lastReroute = _lastRerouteAt;
    if (lastReroute != null && DateTime.now().difference(lastReroute) < const Duration(seconds: 25)) return;
    if (route.geometry.length < 2) return;

    _rerouting = true;
    _lastRerouteAt = DateTime.now();
    if (mounted) setState(() {});
    try {
      final destination = route.geometry.last;
      final response = await AppScope.of(context).api.postJson('/api/v1/map/route', {
        'points': [
          {
            'coord': {'lat': position.latitude, 'lon': position.longitude},
            'name': 'Her',
          },
          {
            'coord': {'lat': destination.lat, 'lon': destination.lon},
            'name': stage.end,
          },
        ],
        'mode': routeModeForTransport(stage.transport),
      });
      final data = response['data'];
      if (data is! Map) return;
      final raw = Map<String, dynamic>.from(data);
      final geometry = (raw['geometry'] as List? ?? const [])
          .whereType<List>()
          .where((point) => point.length >= 2)
          .map((point) => GeoPoint(
                lat: (point[1] as num).toDouble(),
                lon: (point[0] as num).toDouble(),
              ))
          .toList(growable: false);
      if (geometry.length < 2 || !mounted) return;
      final maneuvers = (raw['maneuvers'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => NavigationManeuver.fromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
      setState(() {
        _official = RouteCandidate(
          id: '${route.id}-reroute-${DateTime.now().millisecondsSinceEpoch}',
          name: route.name,
          distanceMeters: (raw['distance'] as num? ?? route.distanceMeters).round(),
          durationSeconds: (raw['duration'] as num? ?? route.durationSeconds).round(),
          geometry: geometry,
          maneuvers: maneuvers,
          guidanceSource: raw['guidanceSource']?.toString() ?? route.guidanceSource,
          official: true,
        );
        _maneuverIndex = 0;
        _lastSpokenBucket = null;
        _offRouteFixes = 0;
        _offRouteDistanceMeters = 0;
        _matchedPoint = GeoPoint(lat: position.latitude, lon: position.longitude);
      });
    } catch (_) {
      // Keep the current official route if rerouting is unavailable.
    } finally {
      _rerouting = false;
      if (mounted) setState(() {});
    }
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
    if (_muted || !_ttsReady || !_running || _arrived) return;
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

  bool _isFinalStage(BuildContext context) {
    final trip = AppScope.of(context).activeTrip;
    final stage = widget.stage;
    if (trip == null || stage == null || trip.stages.isEmpty) return true;
    final ordered = [...trip.stages]..sort((a, b) {
      final day = a.day.compareTo(b.day);
      return day != 0 ? day : a.order.compareTo(b.order);
    });
    return ordered.last.id == stage.id;
  }

  Future<void> _finishNavigation() async {
    final stage = widget.stage;
    _running = false;
    await _positionSub?.cancel();
    _positionSub = null;
    await _tts.stop();
    if (stage != null && mounted) {
      await AppScope.of(context).completeNavigationStage(stage);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _stopNavigation() async {
    _running = false;
    await _positionSub?.cancel();
    _positionSub = null;
    await _tts.stop();
    if (mounted) Navigator.pop(context, false);
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
    final finalStage = _isFinalStage(context);
    final remainingLabel = _remainingMeters >= 1000
        ? '${(_remainingMeters / 1000).toStringAsFixed(_remainingMeters >= 10000 ? 0 : 1)} km'
        : '$_remainingMeters m';

    return Scaffold(
      backgroundColor: GoViaColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          NavigationMapCockpit(
            key: ValueKey('cockpit-${route?.id}-${route?.geometry.length ?? 0}'),
            geometry: route?.geometry ?? const [],
            position: _position == null
                ? null
                : GeoPoint(lat: _position!.latitude, lon: _position!.longitude),
            matchedPoint: _matchedPoint,
            heading: _position?.heading ?? 0,
            speedMetersPerSecond: _position?.speed ?? 0,
            distanceToNextManeuver: distance,
            followUser: _followCamera,
            controlsBottomInset: 205,
            onFollowChanged: (value) => setState(() => _followCamera = value),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .42),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: .58),
                    ],
                    stops: const [0, .18, .63, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                    decoration: BoxDecoration(
                      color: GoViaColors.panel.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: GoViaColors.border),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        Icon(_arrived ? Icons.flag_rounded : _maneuverIcon(maneuver), color: _arrived ? GoViaColors.green : GoViaColors.orange, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _arrived ? 'Fremme' : _distanceLabel(distance),
                                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                _arrived
                                    ? 'Du har nådd ${widget.stage?.end ?? 'målet'}'
                                    : maneuver?.instruction ?? (guidanceAvailable ? 'Venter på posisjon' : 'Manøverdata mangler for denne ruta'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: GoViaColors.muted, fontSize: 15),
                              ),
                              if (derivedGuidance && !_arrived)
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Text('Basisveiledning fra rutegeometri', style: TextStyle(color: GoViaColors.muted, fontSize: 10)),
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusPill(
                      _arrived
                          ? 'Ankommet'
                          : _rerouting
                              ? 'Beregner ny rute…'
                              : _offRouteDistanceMeters > 85
                                  ? 'Utenfor rute · ${_offRouteDistanceMeters.round()} m'
                                  : 'Navigerer · bakgrunn aktiv',
                      color: _arrived
                          ? GoViaColors.green
                          : _rerouting || _offRouteDistanceMeters > 85
                              ? GoViaColors.orange
                              : GoViaColors.cyan,
                      icon: _arrived
                          ? Icons.flag_rounded
                          : _rerouting
                              ? Icons.sync
                              : Icons.navigation_rounded,
                    ),
                  ),
                  if (_positionError != null) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: GoViaColors.panel.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        dense: true,
                        title: Text(_positionError!),
                        trailing: TextButton(onPressed: () => unawaited(_startLocation()), child: const Text('Prøv igjen')),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: GoViaColors.panel.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GoViaColors.border),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _NavMetric(label: 'Igjen', value: _arrived ? '0 m' : remainingLabel, icon: Icons.route)),
                            Expanded(child: _NavMetric(label: 'Tid', value: _arrived ? 'Fremme' : _remainingDuration, icon: Icons.schedule)),
                            Expanded(child: _NavMetric(label: 'GPS', value: _position == null ? 'Venter' : '${((_position!.speed.clamp(0, 100)) * 3.6).round()} km/t', icon: Icons.speed)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (!_arrived) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _running = !_running),
                                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                                  label: Text(_running ? 'Pause' : 'Fortsett'),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _arrived ? GoViaColors.green : GoViaColors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _arrived ? _finishNavigation : _stopNavigation,
                                icon: Icon(_arrived ? Icons.flag_rounded : Icons.stop_rounded),
                                label: Text(_arrived ? (finalStage ? 'Fullfør tur' : 'Fullfør etappe') : 'Stopp navigasjon'),
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
          ),
        ],
      ),
    );
  }
}

class _NavMetric extends StatelessWidget {
  const _NavMetric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: GoViaColors.orange),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: GoViaColors.muted, fontSize: 11)),
          ],
        ),
      );
}
