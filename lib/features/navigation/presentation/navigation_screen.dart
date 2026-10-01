import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';
import '../../../domain/transport_profiles.dart';
import '../domain/route_geometry_utils.dart';
import '../domain/navigation_location_sample.dart';
import '../domain/native_navigation_state.dart';
import '../domain/navigation_reroute_guard.dart';
import '../domain/navigation_voice_localizer.dart';
import 'navigation_map_cockpit.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    this.stage,
    this.locationStream,
    this.rerouteOverride,
    this.developerOverlay,
  });

  final Stage? stage;
  final Stream<NavigationLocationSample>? locationStream;
  final Future<RouteCandidate?> Function(
    NavigationLocationSample position,
    RouteCandidate currentRoute,
    Stage stage,
  )? rerouteOverride;
  final Widget? developerOverlay;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  static const _navigationChannel = MethodChannel('no.govia.mobile/navigation');
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<NavigationLocationSample>? _positionSub;
  RouteCandidate? _official;
  NativeNavigationState? _runtimeState;
  NavigationLocationSample? _position;
  final Set<String> _spokenInstructionIds = <String>{};
  Future<void> _nativeUpdateQueue = Future<void>.value();
  String? _positionError;
  bool _muted = false;
  bool _running = true;
  bool _ttsReady = false;
  bool _sessionPreparing = false;
  bool _preferencesLoaded = false;
  bool _sessionActivated = false;
  GeoPoint? _matchedPoint;
  bool _offRoute = false;
  double _remainingMetersValue = 0;
  int _remainingSecondsValue = 0;
  DateTime? _lastRerouteAt;
  bool _rerouting = false;
  bool _arrived = false;
  bool _arrivalAnnounced = false;
  bool _arrivalDialogShown = false;
  String _navigationLanguage = 'nb';
  int _sessionRevision = 0;

  @override
  void initState() {
    super.initState();
    _official = _findOfficial(widget.stage);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(_setNativeNavigationActive(true));
    unawaited(_startLocation());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (!_preferencesLoaded) {
      _preferencesLoaded = true;
      _muted = !(state.profile?.voiceEnabled ?? true);
      _navigationLanguage = state.navigationLanguage == 'auto'
          ? (Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'nb')
          : state.navigationLanguage;
      unawaited(_configureTts(_navigationLanguage));
    }
    if (!_sessionActivated && !_sessionPreparing && widget.stage != null) {
      _sessionPreparing = true;
      unawaited(_prepareNavigationSession(state));
    }
  }

  Future<void> _setNativeNavigationActive(bool active) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _navigationChannel.invokeMethod<void>('setNavigationActive', {'active': active});
    } catch (_) {
      // PiP is an Android enhancement; navigation itself must continue without it.
    }
  }

  Future<void> _prepareNavigationSession(AppState state) async {
    final stage = widget.stage;
    if (stage == null) return;
    try {
      final route = await _ensureGuidance(_official);
      if (!mounted || route == null) return;
      if (route.geometry.length < 2 || route.maneuvers.isEmpty) {
        if (mounted) setState(() => _positionError = 'Ruten mangler provider-manøverdata og kan ikke starte navigasjon.');
        return;
      }
      _official = route;
      final raw = await _navigationChannel.invokeMethod<Map<dynamic, dynamic>>(
        'startNavigationRuntime',
        _nativeRoutePayload(stage, route),
      );
      if (!mounted || raw == null) return;
      _runtimeState = NativeNavigationState.fromMap(raw);
      _remainingMetersValue = _runtimeState!.remainingMeters;
      _remainingSecondsValue = _runtimeState!.remainingSeconds;
      _matchedPoint = _runtimeState!.snappedPosition;
      _offRoute = _runtimeState!.rerouteRequired;
      _arrived = _runtimeState!.arrived;
      _sessionRevision += 1;
      _sessionActivated = true;
      await state.clearPhoneNavigationRuntime();
      await state.startNavigationStage(stage, navigationRoute: route);
      final pendingPosition = _position;
      if (pendingPosition != null) _onPosition(pendingPosition);
      if (mounted) setState(() {});
    } on MissingPluginException {
      if (mounted) setState(() => _positionError = 'Ferrostar navigation runtime er ikke tilgjengelig på denne plattformen.');
    } catch (error) {
      if (mounted) setState(() => _positionError = 'Kunne ikke starte navigasjon: $error');
    } finally {
      _sessionPreparing = false;
    }
  }

  Map<String, dynamic> _nativeRoutePayload(Stage stage, RouteCandidate route) => {
        'stageId': stage.id,
        'routeId': route.id,
        'name': route.name,
        'start': stage.start,
        'end': stage.end,
        'transport': stage.transport.name,
        'distanceMeters': route.distanceMeters,
        'durationSeconds': route.durationSeconds,
        'routeProfile': stage.routeProfile,
        'routePreferences': stage.routePreferences.toJson(),
        'geometry': [for (final point in route.geometry) [point.lon, point.lat]],
        'maneuvers': [for (final maneuver in route.maneuvers) maneuver.toJson()],
        'speedLimitSections': [for (final section in route.speedLimitSections) section.toJson()],
      };

  Future<RouteCandidate?> _ensureGuidance(RouteCandidate? route) async {
    if (route == null || route.geometry.length < 2) return route;
    // Provider guidance is mandatory. Geometry-derived turn synthesis was removed with
    // Navigation Core v2 and must not return as a fallback.
    return route.maneuvers.isEmpty ? null : route;
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

  Future<void> _configureTts(String language) async {
    try {
      if (language == 'en') {
        await _tts.setLanguage('en-US');
      } else {
        final nb = await _tts.isLanguageAvailable('nb-NO');
        await _tts.setLanguage(nb == true ? 'nb-NO' : 'no-NO');
      }
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
      await _positionSub?.cancel();
      _positionSub = null;
      if (mounted) setState(() => _positionError = null);

      final injected = widget.locationStream;
      if (injected != null) {
        _positionSub = injected.listen(
          _onPosition,
          onError: (Object error) {
            if (mounted) setState(() => _positionError = '$error');
          },
        );
        return;
      }

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

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await Permission.notification.request();
        } catch (_) {
          // Notification permission must never block foreground GPS startup.
        }
      }

      final LocationSettings streamSettings;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        streamSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'GoVia navigerer',
            notificationText: 'Trykk for å gå tilbake til navigasjonen.',
            notificationChannelName: 'GoVia navigasjon',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      } else {
        streamSettings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        );
      }

      // Subscribe to the live stream first. The old order waited for the one-shot
      // fix before starting the stream, which could leave navigation apparently
      // frozen for up to the full timeout on a cold GPS start.
      _positionSub = Geolocator.getPositionStream(locationSettings: streamSettings)
          .map((position) => NavigationLocationSample(
                latitude: position.latitude,
                longitude: position.longitude,
                speedMetersPerSecond: position.speed,
                heading: position.heading,
                timestamp: position.timestamp,
                accuracyMeters: position.accuracy,
              ))
          .listen(
        _onPosition,
        onError: (Object error) {
          if (mounted) setState(() => _positionError = '$error');
        },
      );

      // Prime cockpit immediately while the continuous stream acquires a fresh fix.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && _running) {
        _onPosition(NavigationLocationSample(
          latitude: cached.latitude,
          longitude: cached.longitude,
          speedMetersPerSecond: cached.speed,
          heading: cached.heading,
          timestamp: cached.timestamp,
          accuracyMeters: cached.accuracy,
        ));
      }
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 15),
          ),
        );
        if (_running) {
          _onPosition(NavigationLocationSample(
            latitude: current.latitude,
            longitude: current.longitude,
            speedMetersPerSecond: current.speed,
            heading: current.heading,
            timestamp: current.timestamp,
            accuracyMeters: current.accuracy,
          ));
        }
      } on TimeoutException {
        // Continuous stream is already active and keeps waiting for a fresh fix.
      }
    } catch (error) {
      if (mounted) setState(() => _positionError = '$error');
    }
  }

  void _onPosition(NavigationLocationSample position) {
    if (!_running) return;
    _position = position;
    if (_sessionActivated) {
      _nativeUpdateQueue = _nativeUpdateQueue.then((_) => _updateNativePosition(position));
    }
    if (mounted) setState(() {});
  }

  Future<void> _updateNativePosition(NavigationLocationSample position) async {
    if (!_running || !_sessionActivated) return;
    try {
      final raw = await _navigationChannel.invokeMethod<Map<dynamic, dynamic>>(
        'updateNavigationFix',
        {
          'lat': position.latitude,
          'lon': position.longitude,
          'speedMetersPerSecond': position.speedMetersPerSecond,
          'headingDegrees': position.heading,
          'accuracyMeters': position.accuracyMeters,
          'timestampMillis': position.timestamp.millisecondsSinceEpoch,
        },
      );
      if (!mounted || raw == null) return;
      final state = NativeNavigationState.fromMap(raw);
      if (state.routeId != (_official?.id ?? state.routeId)) return;
      final wasArrived = _arrived;
      _runtimeState = state;
      _matchedPoint = state.snappedPosition;
      _offRoute = state.rerouteRequired;
      _remainingMetersValue = state.remainingMeters;
      _remainingSecondsValue = state.remainingSeconds;
      _arrived = state.arrived;
      if (_arrived && !wasArrived) unawaited(_handleArrival());
      await _announceIfNeeded();
      unawaited(_rerouteIfNeeded());
      if (mounted) setState(() {});
    } on MissingPluginException {
      if (mounted) setState(() => _positionError = 'Ferrostar navigation runtime mistet forbindelsen.');
    } catch (error) {
      if (mounted) setState(() => _positionError = 'Navigasjonsruntime: $error');
    }
  }

  Future<void> _announceArrival() async {
    if (_arrivalAnnounced || _muted || !_ttsReady) return;
    _arrivalAnnounced = true;
    await _tts.stop();
    await _tts.speak(NavigationVoiceLocalizer(_navigationLanguage).arrival());
  }

  Future<void> _handleArrival() async {
    await _announceArrival();
    if (!mounted || _arrivalDialogShown) return;
    _arrivalDialogShown = true;
    final finalStage = _isFinalStage(context);
    final complete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_navigationLanguage == 'en' ? 'You have arrived' : 'Du har kommet frem'),
        content: Text(_navigationLanguage == 'en'
            ? 'Do you want to complete this ${finalStage ? 'trip' : 'stage'} now?'
            : 'Vil du fullføre ${finalStage ? 'turen' : 'etappen'} nå?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_navigationLanguage == 'en' ? 'Keep route open' : 'Behold ruten åpen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_navigationLanguage == 'en' ? 'Complete' : 'Fullfør'),
          ),
        ],
      ),
    );
    if (complete == true && mounted) await _finishNavigation();
  }

  bool _rerouteRequestStillCurrent(NavigationRerouteRequestIdentity request) {
    if (!mounted) return false;
    final currentTripId = AppScope.of(context).activeTrip?.id ?? '';
    return request.matches(
      currentTripId: currentTripId,
      currentStageId: widget.stage?.id ?? '',
      currentRouteId: _official?.id ?? '',
      currentSessionRevision: _sessionRevision,
    );
  }

  Future<void> _rerouteIfNeeded() async {
    final stage = widget.stage;
    final position = _position;
    final route = _official;
    if (stage == null || position == null || route == null || _arrived || _rerouting || _runtimeState?.rerouteRequired != true) return;
    if (stage.transport == StageTransport.train || stage.transport == StageTransport.ferry) return;
    final lastReroute = _lastRerouteAt;
    if (lastReroute != null && DateTime.now().difference(lastReroute) < const Duration(seconds: 25)) return;
    if (route.geometry.length < 2) return;

    final appState = AppScope.of(context);
    final api = appState.api;
    final request = NavigationRerouteRequestIdentity(
      tripId: appState.activeTrip?.id ?? '',
      stageId: stage.id,
      routeId: route.id,
      sessionRevision: _sessionRevision,
    );
    _rerouting = true;
    _lastRerouteAt = DateTime.now();
    if (mounted) setState(() {});
    try {
      final override = widget.rerouteOverride;
      if (override != null) {
        final replacement = await override(position, route, stage);
        if (replacement != null && _rerouteRequestStillCurrent(request)) {
          await _applyReroute(replacement, stage, position, request);
          return;
        }
      }

      final destination = route.geometry.last;
      final points = [
        {
          'coord': {'lat': position.latitude, 'lon': position.longitude},
          'name': 'Her',
        },
        {
          'coord': {'lat': destination.lat, 'lon': destination.lon},
          'name': stage.end,
        },
      ];
      late Map<String, dynamic> response;
      try {
        response = await api.postJson('/api/v1/map/route', {
          'points': points,
          'mode': routeModeForTransport(stage.transport),
          'profile': stage.routeProfile,
          'preferences': stage.routePreferences.toJson(),
        });
      } catch (_) {
        response = await api.postJson('/api/v1/map/route', {
          'points': points,
          'mode': routeModeForTransport(stage.transport),
        });
      }
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
      final replacement = RouteCandidate(
        id: '${route.id}-reroute-${DateTime.now().millisecondsSinceEpoch}',
        name: route.name,
        distanceMeters: (raw['distance'] as num? ?? route.distanceMeters).round(),
        durationSeconds: (raw['duration'] as num? ?? route.durationSeconds).round(),
        geometry: geometry,
        maneuvers: maneuvers,
        speedLimitSections: RouteSpeedLimitSection.fromRouteJson(raw, geometry),
        guidanceSource: raw['guidanceSource']?.toString() ?? route.guidanceSource,
        official: true,
      );
      if (_rerouteRequestStillCurrent(request)) {
        await _applyReroute(replacement, stage, position, request);
      }
    } catch (_) {
      // Keep the current official route if rerouting is unavailable.
    } finally {
      _rerouting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _applyReroute(
    RouteCandidate replacement,
    Stage stage,
    NavigationLocationSample position,
    NavigationRerouteRequestIdentity request,
  ) async {
    final appScope = AppScope.of(context);
    final withGuidance = await _ensureGuidance(replacement);
    if (withGuidance == null || withGuidance.maneuvers.isEmpty || !_rerouteRequestStillCurrent(request)) return;
    final reprojectedWaypoints = reprojectStageWaypoints(stage.waypoints, withGuidance.geometry);
    final reroutedStage = stage.copyWith(waypoints: reprojectedWaypoints);
    final raw = await _navigationChannel.invokeMethod<Map<dynamic, dynamic>>(
      'replaceNavigationRoute',
      _nativeRoutePayload(reroutedStage, withGuidance),
    );
    if (raw == null || !_rerouteRequestStillCurrent(request)) return;
    _runtimeState = NativeNavigationState.fromMap(raw);
    _sessionRevision += 1;
    _official = withGuidance;
    _spokenInstructionIds.clear();
    _offRoute = false;
    _matchedPoint = _runtimeState?.snappedPosition ?? GeoPoint(lat: position.latitude, lon: position.longitude);
    _remainingMetersValue = _runtimeState?.remainingMeters ?? withGuidance.distanceMeters.toDouble();
    _remainingSecondsValue = _runtimeState?.remainingSeconds ?? withGuidance.durationSeconds;
    await appScope.updateNavigationStageRoute(stage.id, withGuidance, waypoints: reprojectedWaypoints);
    _onPosition(position);
  }

  NavigationManeuver? get _currentManeuver => _runtimeState?.currentManeuver;

  double? get _distanceToManeuver => _runtimeState?.distanceToManeuverMeters;

  Future<void> _announceIfNeeded() async {
    if (_muted || !_ttsReady || !_running || _arrived) return;
    final id = _runtimeState?.spokenInstructionId;
    final maneuver = _runtimeState?.currentManeuver;
    if (id == null || maneuver == null || !_spokenInstructionIds.add(id)) return;
    final text = NavigationVoiceLocalizer(_navigationLanguage).instruction(
      maneuver,
      distanceMeters: _runtimeState?.distanceToManeuverMeters,
    );
    await _tts.stop();
    await _tts.speak(text);
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

  int get _remainingMeters => _remainingMetersValue.round().clamp(0, 1 << 31).toInt();

  String get _remainingDuration {
    if (_official == null) return '—';
    final seconds = _remainingSecondsValue;
    final minutes = (seconds / 60).round();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}t ${m}m' : '${m}m';
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    if (_muted) {
      await _tts.stop();
    }
    _spokenInstructionIds.clear();
  }

  bool _isFinalStage(BuildContext context) {
    final trip = AppScope.of(context).activeTrip;
    final stage = widget.stage;
    if (trip == null || stage == null || trip.stages.isEmpty) return true;
    return trip.stages.every((item) => item.id == stage.id || item.status == StageStatus.completed);
  }

  Future<void> _finishNavigation() async {
    final stage = widget.stage;
    final state = AppScope.of(context);
    final tripBeforeCompletion = state.activeTrip;
    final nextStage = stage != null && tripBeforeCompletion != null ? state.nextStageAfter(tripBeforeCompletion, stage) : null;
    _running = false;
    await _setNativeNavigationActive(false);
    try { await _navigationChannel.invokeMethod<void>('stopNavigationRuntime'); } catch (_) {}
    await _positionSub?.cancel();
    _positionSub = null;
    await _tts.stop();
    await state.clearPhoneNavigationRuntime();
    if (stage != null) {
      await state.completeNavigationStage(stage);
    }
    if (!mounted) return;

    final nextNavigable = nextStage != null &&
        nextStage.transport != StageTransport.ferry &&
        nextStage.transport != StageTransport.train;
    if (nextStage != null) {
      final startNext = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Etappe fullført'),
          content: Text(nextNavigable
              ? 'Neste etappe er ${nextStage.start} → ${nextStage.end}. Vil du starte den nå?'
              : 'Neste etappe er ${nextStage.start} → ${nextStage.end} (${transportLabel(nextStage.transport)}).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Til etapper')),
            if (nextNavigable) FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Start neste etappe')),
          ],
        ),
      );
      if (!mounted) return;
      if (startNext == true && nextNavigable) {
        await state.startNavigationStage(nextStage);
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.navigation, arguments: nextStage);
        return;
      }
      Navigator.pushReplacementNamed(context, AppRoutes.stages, arguments: state.activeTrip ?? tripBeforeCompletion);
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _stopNavigation() async {
    final finalStage = _isFinalStage(context);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_navigationLanguage == 'en' ? 'Stop navigation' : 'Stopp navigasjon'),
        content: Text(_navigationLanguage == 'en'
            ? 'Do you want to stop guidance or complete this ${finalStage ? 'trip' : 'stage'}?'
            : 'Vil du avslutte veiledningen eller fullføre ${finalStage ? 'turen' : 'etappen'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'continue'), child: Text(_navigationLanguage == 'en' ? 'Continue' : 'Fortsett')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'stop'), child: Text(_navigationLanguage == 'en' ? 'Stop guidance' : 'Avslutt navigasjon')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'complete'), child: Text(_navigationLanguage == 'en' ? 'Complete' : 'Fullfør')),
        ],
      ),
    );
    if (!mounted || action == null || action == 'continue') return;
    if (action == 'complete') {
      await _finishNavigation();
      return;
    }
    _running = false;
    await AppScope.of(context).clearPhoneNavigationRuntime();
    await _setNativeNavigationActive(false);
    try { await _navigationChannel.invokeMethod<void>('stopNavigationRuntime'); } catch (_) {}
    await _positionSub?.cancel();
    _positionSub = null;
    await _tts.stop();
    if (mounted) Navigator.pop(context, false);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _tts.stop();
    unawaited(_setNativeNavigationActive(false));
    unawaited(_navigationChannel.invokeMethod<void>('stopNavigationRuntime').catchError((_) {}));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = _official;
    final maneuver = _currentManeuver;
    final distance = _distanceToManeuver;
    final guidanceAvailable = route != null && route.maneuvers.isNotEmpty;
    final activeSpeedLimitKph = _runtimeState?.speedLimitKph;
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
            speedMetersPerSecond: _position?.speedMetersPerSecond ?? 0,
            distanceToNextManeuver: distance,
            controlsBottomInset: 205,
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
          if (activeSpeedLimitKph != null)
            Positioned(
              top: 150,
              right: 18,
              child: SafeArea(
                child: IgnorePointer(
                  child: _RoadSpeedLimitSign(speedLimitKph: activeSpeedLimitKph),
                ),
              ),
            ),
          if (widget.developerOverlay != null) widget.developerOverlay!,
          if (widget.developerOverlay != null)
            Positioned(
              left: 12,
              top: 148,
              child: SafeArea(
                child: IgnorePointer(
                  child: _NavigationSpeedLimitDiagnostics(
                    progressMeters: _runtimeState?.progressMeters ?? 0,
                    sectionCount: route?.speedLimitSections.length ?? 0,
                    speedLimitKph: activeSpeedLimitKph,
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
                                    : maneuver != null
                                        ? NavigationVoiceLocalizer(_navigationLanguage).displayInstruction(maneuver)
                                        : (guidanceAvailable ? 'Venter på posisjon' : 'Manøverdata mangler for denne ruta'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: GoViaColors.muted, fontSize: 15),
                              ),
                              if (!_arrived && _runtimeState?.nextManeuver != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    NavigationVoiceLocalizer(_navigationLanguage).displayInstruction(_runtimeState!.nextManeuver!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: GoViaColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
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
                              : _offRoute
                                  ? 'Utenfor rute'
                                  : 'Navigerer · bakgrunn aktiv',
                      color: _arrived
                          ? GoViaColors.green
                          : _rerouting || _offRoute
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
                            Expanded(child: _NavMetric(label: 'GPS', value: _position == null ? 'Venter' : '${((_position!.speedMetersPerSecond.clamp(0, 100)) * 3.6).round()} km/t', icon: Icons.speed)),
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

class _RoadSpeedLimitSign extends StatelessWidget {
  const _RoadSpeedLimitSign({required this.speedLimitKph});

  final int speedLimitKph;

  @override
  Widget build(BuildContext context) => Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD71920), width: 6),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Text(
          '$speedLimitKph',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      );
}

class _NavigationSpeedLimitDiagnostics extends StatelessWidget {
  const _NavigationSpeedLimitDiagnostics({
    required this.progressMeters,
    required this.sectionCount,
    required this.speedLimitKph,
  });

  final double progressMeters;
  final int sectionCount;
  final int? speedLimitKph;

  @override
  Widget build(BuildContext context) {
    final active = speedLimitKph == null ? 'ukjent' : '$speedLimitKph km/t';
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE61B1F25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GoViaColors.orange.withValues(alpha: .65)),
      ),
      child: Text(
        'DEV speed-limit\n'
        'Progress: ${progressMeters.round()} m\n'
        'Sections: $sectionCount\n'
        'Active: $active\n'
        'Runtime: Ferrostar',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
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
