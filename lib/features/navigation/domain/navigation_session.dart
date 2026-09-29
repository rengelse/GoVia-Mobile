import 'dart:math' as math;

import '../../../domain/models.dart';
import 'navigation_route.dart';

enum NavigationGpsQuality { unknown, good, degraded, poor }
enum NavigationOffRouteState { onRoute, suspect, offRoute }
enum NavigationRerouteState { idle, requested, applying }
enum NavigationArrivalState { navigating, approaching, arrived }

class NavigationFix {
  const NavigationFix({
    required this.lat,
    required this.lon,
    required this.speedMetersPerSecond,
    required this.timestamp,
    this.headingDegrees = 0,
    this.accuracyMeters = 999,
  });

  final double lat;
  final double lon;
  final double speedMetersPerSecond;
  final double headingDegrees;
  final double accuracyMeters;
  final DateTime timestamp;
}

class NavigationSessionSnapshot {
  const NavigationSessionSnapshot({
    required this.progressMeters,
    required this.matchedSegmentIndex,
    required this.maneuverIndex,
    required this.offRouteFixes,
    required this.arrivalFixes,
    required this.firstProgressMeters,
    required this.rerouteState,
    this.currentFix,
    this.smoothedMovingSpeed,
    this.firstFixAt,
    this.lastAcceptedFixAt,
    this.lastSeenFixAt,
  });

  final NavigationFix? currentFix;
  final double progressMeters;
  final int matchedSegmentIndex;
  final int maneuverIndex;
  final int offRouteFixes;
  final int arrivalFixes;
  final double? smoothedMovingSpeed;
  final DateTime? firstFixAt;
  final DateTime? lastAcceptedFixAt;
  final DateTime? lastSeenFixAt;
  final double firstProgressMeters;
  final NavigationRerouteState rerouteState;

  Map<String, dynamic> toJson() => {
        'currentFix': currentFix == null
            ? null
            : {
                'lat': currentFix!.lat,
                'lon': currentFix!.lon,
                'speedMetersPerSecond': currentFix!.speedMetersPerSecond,
                'headingDegrees': currentFix!.headingDegrees,
                'accuracyMeters': currentFix!.accuracyMeters,
                'timestamp': currentFix!.timestamp.toIso8601String(),
              },
        'progressMeters': progressMeters,
        'matchedSegmentIndex': matchedSegmentIndex,
        'maneuverIndex': maneuverIndex,
        'offRouteFixes': offRouteFixes,
        'arrivalFixes': arrivalFixes,
        'smoothedMovingSpeed': smoothedMovingSpeed,
        'firstFixAt': firstFixAt?.toIso8601String(),
        'lastAcceptedFixAt': lastAcceptedFixAt?.toIso8601String(),
        'lastSeenFixAt': lastSeenFixAt?.toIso8601String(),
        'firstProgressMeters': firstProgressMeters,
        'rerouteState': rerouteState.name,
      };

  factory NavigationSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final current = json['currentFix'];
    NavigationFix? fix;
    if (current is Map) {
      final row = Map<String, dynamic>.from(current);
      final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      if (timestamp != null) {
        fix = NavigationFix(
          lat: (row['lat'] as num? ?? 0).toDouble(),
          lon: (row['lon'] as num? ?? 0).toDouble(),
          speedMetersPerSecond: (row['speedMetersPerSecond'] as num? ?? 0).toDouble(),
          headingDegrees: (row['headingDegrees'] as num? ?? 0).toDouble(),
          accuracyMeters: (row['accuracyMeters'] as num? ?? 999).toDouble(),
          timestamp: timestamp,
        );
      }
    }
    return NavigationSessionSnapshot(
      currentFix: fix,
      progressMeters: (json['progressMeters'] as num? ?? 0).toDouble(),
      matchedSegmentIndex: (json['matchedSegmentIndex'] as num? ?? 0).round(),
      maneuverIndex: (json['maneuverIndex'] as num? ?? 0).round(),
      offRouteFixes: (json['offRouteFixes'] as num? ?? 0).round(),
      arrivalFixes: (json['arrivalFixes'] as num? ?? 0).round(),
      smoothedMovingSpeed: (json['smoothedMovingSpeed'] as num?)?.toDouble(),
      firstFixAt: DateTime.tryParse(json['firstFixAt']?.toString() ?? ''),
      lastAcceptedFixAt: DateTime.tryParse(json['lastAcceptedFixAt']?.toString() ?? ''),
      lastSeenFixAt: DateTime.tryParse(json['lastSeenFixAt']?.toString() ?? ''),
      firstProgressMeters: (json['firstProgressMeters'] as num? ?? 0).toDouble(),
      rerouteState: NavigationRerouteState.values.firstWhere(
        (value) => value.name == json['rerouteState']?.toString(),
        orElse: () => NavigationRerouteState.idle,
      ),
    );
  }
}

class NavigationSessionState {
  const NavigationSessionState({
    required this.route,
    required this.currentFix,
    required this.matchedPoint,
    required this.matchedSegmentIndex,
    required this.progressMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.offRouteDistanceMeters,
    required this.offRouteState,
    required this.rerouteState,
    required this.arrivalState,
    required this.gpsQuality,
    required this.currentManeuver,
    required this.nextManeuver,
    required this.distanceToManeuverMeters,
  });

  final NavigationRoute route;
  final NavigationFix? currentFix;
  final GeoPoint? matchedPoint;
  final int matchedSegmentIndex;
  final double progressMeters;
  final double remainingMeters;
  final int remainingSeconds;
  final double offRouteDistanceMeters;
  final NavigationOffRouteState offRouteState;
  final NavigationRerouteState rerouteState;
  final NavigationArrivalState arrivalState;
  final NavigationGpsQuality gpsQuality;
  final NavigationManeuver? currentManeuver;
  final NavigationManeuver? nextManeuver;
  final double? distanceToManeuverMeters;

  bool get arrived => arrivalState == NavigationArrivalState.arrived;
  bool get rerouteRequired => offRouteState == NavigationOffRouteState.offRoute && !arrived;
}

/// Authoritative runtime model for one active Stage.
class NavigationSession {
  NavigationSession(NavigationRoute route)
      : _plannedRoute = route,
        _activeRoute = route {
    _resetRouteDerivedState();
  }

  final NavigationRoute _plannedRoute;
  NavigationRoute _activeRoute;
  late List<double> _cumulative;
  double _progressMeters = 0;
  int _matchedSegmentIndex = 0;
  int _maneuverIndex = 0;
  int _offRouteFixes = 0;
  int _arrivalFixes = 0;
  double? _smoothedMovingSpeed;
  DateTime? _firstFixAt;
  DateTime? _lastAcceptedFixAt;
  DateTime? _lastSeenFixAt;
  double _firstProgressMeters = 0;
  NavigationRerouteState _rerouteState = NavigationRerouteState.idle;
  NavigationSessionState? _state;

  NavigationRoute get route => _activeRoute;
  NavigationRoute get plannedRoute => _plannedRoute;
  NavigationRoute get activeRoute => _activeRoute;
  NavigationSessionState? get state => _state;

  void replaceRoute(NavigationRoute route) {
    if (route.stageId != _activeRoute.stageId) {
      throw StateError('NavigationSession cannot replace its active Stage.');
    }
    _activeRoute = route;
    _resetRouteDerivedState();
  }

  NavigationSessionSnapshot snapshot() => NavigationSessionSnapshot(
        currentFix: _state?.currentFix,
        progressMeters: _progressMeters,
        matchedSegmentIndex: _matchedSegmentIndex,
        maneuverIndex: _maneuverIndex,
        offRouteFixes: _offRouteFixes,
        arrivalFixes: _arrivalFixes,
        smoothedMovingSpeed: _smoothedMovingSpeed,
        firstFixAt: _firstFixAt,
        lastAcceptedFixAt: _lastAcceptedFixAt,
        lastSeenFixAt: _lastSeenFixAt,
        firstProgressMeters: _firstProgressMeters,
        rerouteState: _rerouteState,
      );

  void restore(NavigationSessionSnapshot snapshot) {
    final maxProgress = _cumulative.isEmpty ? 0.0 : _cumulative.last;
    _progressMeters = snapshot.progressMeters.clamp(0.0, maxProgress).toDouble();
    _matchedSegmentIndex = snapshot.matchedSegmentIndex.clamp(0, math.max(0, _activeRoute.geometry.length - 2)).toInt();
    _maneuverIndex = snapshot.maneuverIndex.clamp(0, math.max(0, _activeRoute.maneuvers.length - 1)).toInt();
    _offRouteFixes = snapshot.offRouteFixes.clamp(0, 3).toInt();
    _arrivalFixes = snapshot.arrivalFixes.clamp(0, 3).toInt();
    _smoothedMovingSpeed = snapshot.smoothedMovingSpeed;
    _firstFixAt = snapshot.firstFixAt;
    _lastAcceptedFixAt = snapshot.lastAcceptedFixAt;
    _lastSeenFixAt = snapshot.lastSeenFixAt ?? snapshot.lastAcceptedFixAt;
    _firstProgressMeters = math.max(0.0, snapshot.firstProgressMeters);
    _rerouteState = snapshot.rerouteState == NavigationRerouteState.requested ||
            snapshot.rerouteState == NavigationRerouteState.applying
        ? NavigationRerouteState.idle
        : snapshot.rerouteState;
    _state = _restoredState(snapshot.currentFix);
  }

  NavigationSessionState _restoredState(NavigationFix? fix) {
    final routeLength = _cumulative.isEmpty ? _activeRoute.distanceMeters.toDouble() : _cumulative.last;
    final remaining = math.max(0.0, routeLength - _progressMeters);
    final offRouteState = _offRouteFixes >= 3
        ? NavigationOffRouteState.offRoute
        : _offRouteFixes > 0
            ? NavigationOffRouteState.suspect
            : NavigationOffRouteState.onRoute;
    final destination = _activeRoute.geometry.lastOrNull;
    final destinationDistance = fix == null || destination == null
        ? null
        : haversineMeters(fix.lat, fix.lon, destination.lat, destination.lon);
    final arrivalState = _arrivalFixes >= 3
        ? NavigationArrivalState.arrived
        : destinationDistance != null && destinationDistance <= 180
            ? NavigationArrivalState.approaching
            : NavigationArrivalState.navigating;
    final anchored = _activeRoute.maneuvers.isEmpty ? null : _activeRoute.maneuvers[_maneuverIndex];
    return NavigationSessionState(
      route: _activeRoute,
      currentFix: fix,
      matchedPoint: _activeRoute.geometry.isEmpty ? null : _activeRoute.geometry[_matchedSegmentIndex.clamp(0, _activeRoute.geometry.length - 1).toInt()],
      matchedSegmentIndex: _matchedSegmentIndex,
      progressMeters: _progressMeters,
      remainingMeters: arrivalState == NavigationArrivalState.arrived ? 0 : remaining,
      remainingSeconds: arrivalState == NavigationArrivalState.arrived
          ? 0
          : _estimateRemainingSeconds(remaining, fix?.timestamp ?? DateTime.now()),
      offRouteDistanceMeters: 0,
      offRouteState: arrivalState == NavigationArrivalState.arrived ? NavigationOffRouteState.onRoute : offRouteState,
      rerouteState: _rerouteState,
      arrivalState: arrivalState,
      gpsQuality: fix == null ? NavigationGpsQuality.unknown : _gpsQuality(fix.accuracyMeters),
      currentManeuver: arrivalState == NavigationArrivalState.arrived ? null : anchored?.maneuver,
      nextManeuver: arrivalState == NavigationArrivalState.arrived
          ? null
          : (_maneuverIndex + 1 < _activeRoute.maneuvers.length ? _activeRoute.maneuvers[_maneuverIndex + 1].maneuver : null),
      distanceToManeuverMeters: arrivalState == NavigationArrivalState.arrived || anchored == null
          ? null
          : math.max(0.0, anchored.routeProgressMeters - _progressMeters),
    );
  }

  void setRerouteState(NavigationRerouteState state) {
    _rerouteState = state;
    final current = _state;
    if (current != null) {
      _state = NavigationSessionState(
        route: current.route,
        currentFix: current.currentFix,
        matchedPoint: current.matchedPoint,
        matchedSegmentIndex: current.matchedSegmentIndex,
        progressMeters: current.progressMeters,
        remainingMeters: current.remainingMeters,
        remainingSeconds: current.remainingSeconds,
        offRouteDistanceMeters: current.offRouteDistanceMeters,
        offRouteState: current.offRouteState,
        rerouteState: state,
        arrivalState: current.arrivalState,
        gpsQuality: current.gpsQuality,
        currentManeuver: current.currentManeuver,
        nextManeuver: current.nextManeuver,
        distanceToManeuverMeters: current.distanceToManeuverMeters,
      );
    }
  }

  NavigationSessionState update(NavigationFix fix) {
    final geometry = _activeRoute.geometry;
    if (geometry.length < 2 || _cumulative.length != geometry.length) {
      return _state = _emptyState(fix);
    }

    final current = _state;
    if (current?.arrived == true) {
      return current!;
    }

    final lastSeen = _lastSeenFixAt;
    if (lastSeen != null && !fix.timestamp.isAfter(lastSeen)) {
      return current ?? _emptyState(fix);
    }
    _lastSeenFixAt = fix.timestamp;

    final lastAccepted = _lastAcceptedFixAt;
    final gpsQuality = _gpsQuality(fix.accuracyMeters);
    if (gpsQuality == NavigationGpsQuality.poor || gpsQuality == NavigationGpsQuality.unknown) {
      return _state = current == null
          ? _emptyState(fix)
          : _copyWithFix(current, fix, gpsQuality);
    }

    final projection = _bestProjection(fix);
    final elapsedSeconds = lastAccepted == null
        ? 1.0
        : math.max(.2, fix.timestamp.difference(lastAccepted).inMilliseconds / 1000.0);
    final speed = fix.speedMetersPerSecond.isFinite
        ? fix.speedMetersPerSecond.clamp(0.0, 80.0).toDouble()
        : 0.0;
    final maxForwardJump = math.max(120.0, speed * elapsedSeconds * 4 + math.max(80.0, fix.accuracyMeters * 2));
    final backwardsAllowance = math.max(35.0, math.min(75.0, fix.accuracyMeters * 1.25));

    final hasContinuity = lastAccepted != null || _progressMeters > 0;
    final projectionAccepted = !hasContinuity ||
        (projection.progressMeters >= _progressMeters - backwardsAllowance &&
            projection.progressMeters <= _progressMeters + maxForwardJump);
    if (!projectionAccepted) {
      return _state = current == null
          ? _emptyState(fix)
          : _copyWithFix(current, fix, gpsQuality);
    }

    _progressMeters = math.max(_progressMeters, projection.progressMeters);
    _matchedSegmentIndex = projection.segmentIndex;
    _lastAcceptedFixAt = fix.timestamp;

    _firstFixAt ??= fix.timestamp;
    if (_firstProgressMeters == 0) _firstProgressMeters = _progressMeters;
    if (speed >= 1.5) {
      _smoothedMovingSpeed = _smoothedMovingSpeed == null
          ? speed
          : (_smoothedMovingSpeed! * .82 + speed * .18);
    }

    final routeLength = _cumulative.last;
    final remaining = math.max(0.0, routeLength - _progressMeters);
    final offRouteThreshold = math.max(70.0, math.min(160.0, fix.accuracyMeters * 2));
    if (projection.distanceMeters > offRouteThreshold) {
      _offRouteFixes += 1;
    } else {
      _offRouteFixes = 0;
    }
    final offRouteState = _offRouteFixes >= 3
        ? NavigationOffRouteState.offRoute
        : _offRouteFixes > 0
            ? NavigationOffRouteState.suspect
            : NavigationOffRouteState.onRoute;

    final destination = geometry.last;
    final destinationDistance = haversineMeters(fix.lat, fix.lon, destination.lat, destination.lon);
    final accuracy = fix.accuracyMeters.isFinite ? fix.accuracyMeters.clamp(0.0, 250.0).toDouble() : 250.0;
    final preciseRadius = math.max(25.0, math.min(45.0, accuracy * 1.25));
    final credibleArrival = destinationDistance <= preciseRadius ||
        (destinationDistance <= 55 && speed <= 5 && accuracy <= 35);
    if (credibleArrival) {
      _arrivalFixes += 1;
    } else if (destinationDistance > 80) {
      _arrivalFixes = 0;
    }
    final arrivalState = _arrivalFixes >= 3
        ? NavigationArrivalState.arrived
        : destinationDistance <= 180
            ? NavigationArrivalState.approaching
            : NavigationArrivalState.navigating;

    _advanceManeuverIndex();
    final currentManeuver = _currentManeuver();
    final nextManeuver = _nextManeuver();
    final distanceToManeuver = currentManeuver == null
        ? null
        : math.max(0.0, _activeRoute.maneuvers[_maneuverIndex].routeProgressMeters - _progressMeters);

    final matchedPoint = projection.distanceMeters <= math.max(140.0, accuracy * 2.5)
        ? projection.point
        : null;

    return _state = NavigationSessionState(
      route: _activeRoute,
      currentFix: fix,
      matchedPoint: matchedPoint,
      matchedSegmentIndex: _matchedSegmentIndex,
      progressMeters: _progressMeters,
      remainingMeters: arrivalState == NavigationArrivalState.arrived ? 0 : remaining,
      remainingSeconds: arrivalState == NavigationArrivalState.arrived ? 0 : _estimateRemainingSeconds(remaining, fix.timestamp),
      offRouteDistanceMeters: projection.distanceMeters,
      offRouteState: arrivalState == NavigationArrivalState.arrived ? NavigationOffRouteState.onRoute : offRouteState,
      rerouteState: _rerouteState,
      arrivalState: arrivalState,
      gpsQuality: gpsQuality,
      currentManeuver: arrivalState == NavigationArrivalState.arrived ? null : currentManeuver,
      nextManeuver: arrivalState == NavigationArrivalState.arrived ? null : nextManeuver,
      distanceToManeuverMeters: arrivalState == NavigationArrivalState.arrived ? null : distanceToManeuver,
    );
  }

  void _resetRouteDerivedState() {
    _cumulative = cumulativeDistances(_activeRoute.geometry);
    _progressMeters = 0;
    _matchedSegmentIndex = 0;
    _maneuverIndex = 0;
    _offRouteFixes = 0;
    _arrivalFixes = 0;
    _smoothedMovingSpeed = null;
    _firstFixAt = null;
    _lastAcceptedFixAt = null;
    _lastSeenFixAt = null;
    _firstProgressMeters = 0;
    _rerouteState = NavigationRerouteState.idle;
    _state = null;
  }

  NavigationSessionState _emptyState(NavigationFix fix) => NavigationSessionState(
        route: _activeRoute,
        currentFix: fix,
        matchedPoint: null,
        matchedSegmentIndex: 0,
        progressMeters: 0,
        remainingMeters: _activeRoute.distanceMeters.toDouble(),
        remainingSeconds: _activeRoute.durationSeconds,
        offRouteDistanceMeters: 0,
        offRouteState: NavigationOffRouteState.onRoute,
        rerouteState: _rerouteState,
        arrivalState: NavigationArrivalState.navigating,
        gpsQuality: _gpsQuality(fix.accuracyMeters),
        currentManeuver: _activeRoute.maneuvers.firstOrNull?.maneuver,
        nextManeuver: _activeRoute.maneuvers.length > 1 ? _activeRoute.maneuvers[1].maneuver : null,
        distanceToManeuverMeters: _activeRoute.maneuvers.firstOrNull?.routeProgressMeters,
      );

  NavigationSessionState _copyWithFix(
    NavigationSessionState value,
    NavigationFix fix,
    NavigationGpsQuality gpsQuality,
  ) => NavigationSessionState(
        route: value.route,
        currentFix: fix,
        matchedPoint: value.matchedPoint,
        matchedSegmentIndex: value.matchedSegmentIndex,
        progressMeters: value.progressMeters,
        remainingMeters: value.remainingMeters,
        remainingSeconds: value.remainingSeconds,
        offRouteDistanceMeters: value.offRouteDistanceMeters,
        offRouteState: value.offRouteState,
        rerouteState: value.rerouteState,
        arrivalState: value.arrivalState,
        gpsQuality: gpsQuality,
        currentManeuver: value.currentManeuver,
        nextManeuver: value.nextManeuver,
        distanceToManeuverMeters: value.distanceToManeuverMeters,
      );

  void _advanceManeuverIndex() {
    while (_maneuverIndex < _activeRoute.maneuvers.length - 1 &&
        _activeRoute.maneuvers[_maneuverIndex].routeProgressMeters <= _progressMeters + 20) {
      _maneuverIndex += 1;
    }
  }

  NavigationManeuver? _currentManeuver() =>
      _activeRoute.maneuvers.isEmpty ? null : _activeRoute.maneuvers[_maneuverIndex].maneuver;

  NavigationManeuver? _nextManeuver() => _activeRoute.maneuvers.isEmpty || _maneuverIndex >= _activeRoute.maneuvers.length - 1
      ? null
      : _activeRoute.maneuvers[_maneuverIndex + 1].maneuver;

  int _estimateRemainingSeconds(double remainingMeters, DateTime now) {
    if (remainingMeters <= 0) return 0;
    final totalDistance = math.max(1.0, _cumulative.isEmpty ? _activeRoute.distanceMeters.toDouble() : _cumulative.last);
    final baselineSeconds = math.max(1, _activeRoute.durationSeconds);
    final baselineSpeed = totalDistance / baselineSeconds;
    double? observedSpeed;
    final first = _firstFixAt;
    if (first != null) {
      final elapsed = now.difference(first).inMilliseconds / 1000.0;
      final progressed = math.max(0.0, _progressMeters - _firstProgressMeters);
      if (elapsed >= 90 && progressed >= 500) observedSpeed = progressed / elapsed;
    }
    var effectiveSpeed = baselineSpeed;
    if (observedSpeed != null && observedSpeed >= 1.5) {
      effectiveSpeed = baselineSpeed * .45 + observedSpeed * .55;
    }
    final movingSpeed = _smoothedMovingSpeed;
    if (movingSpeed != null && movingSpeed >= 1.5) {
      effectiveSpeed = effectiveSpeed * .75 + movingSpeed * .25;
    }
    effectiveSpeed = effectiveSpeed.clamp(baselineSpeed * .45, baselineSpeed * 1.35).toDouble();
    return (remainingMeters / math.max(.8, effectiveSpeed)).round();
  }

  _RouteProjection _bestProjection(NavigationFix fix) {
    final geometry = _activeRoute.geometry;
    final start = math.max(0, _matchedSegmentIndex - 18);
    final end = math.min(geometry.length - 2, _matchedSegmentIndex + 90);
    var best = _scanProjectionRange(fix, start, end);
    if (best.distanceMeters > 180 || _lastAcceptedFixAt == null) {
      final global = _scanProjectionRange(fix, 0, geometry.length - 2);
      if (global.score < best.score) best = global;
    }
    return best;
  }

  _RouteProjection _scanProjectionRange(NavigationFix fix, int start, int end) {
    final geometry = _activeRoute.geometry;
    var best = _RouteProjection(
      segmentIndex: start,
      progressMeters: _cumulative[start],
      distanceMeters: double.infinity,
      point: geometry[start],
      score: double.infinity,
    );
    final hasHeading = fix.speedMetersPerSecond >= 1.5 && fix.headingDegrees.isFinite && fix.headingDegrees >= 0;
    for (var i = start; i <= end; i++) {
      final projection = projectToSegment(fix.lat, fix.lon, geometry[i], geometry[i + 1]);
      final progress = _cumulative[i] + projection.segmentMeters * projection.t;
      final continuityPenalty = _lastAcceptedFixAt == null ? 0.0 : math.min(160.0, (i - _matchedSegmentIndex).abs() * 1.8);
      final backwardPenalty = progress < _progressMeters - 45 ? math.min(300.0, (_progressMeters - progress) * .55) : 0.0;
      final headingPenalty = hasHeading
          ? headingDeltaDegrees(fix.headingDegrees, bearingDegrees(geometry[i], geometry[i + 1])) * .55
          : 0.0;
      final score = projection.distanceMeters + continuityPenalty + backwardPenalty + headingPenalty;
      if (score < best.score) {
        best = _RouteProjection(
          segmentIndex: i,
          progressMeters: progress,
          distanceMeters: projection.distanceMeters,
          point: projection.point,
          score: score,
        );
      }
    }
    return best;
  }

  NavigationGpsQuality _gpsQuality(double accuracy) {
    if (!accuracy.isFinite || accuracy <= 0) return NavigationGpsQuality.unknown;
    if (accuracy <= 25) return NavigationGpsQuality.good;
    if (accuracy <= 80) return NavigationGpsQuality.degraded;
    return NavigationGpsQuality.poor;
  }
}

class _RouteProjection {
  const _RouteProjection({
    required this.segmentIndex,
    required this.progressMeters,
    required this.distanceMeters,
    required this.point,
    required this.score,
  });

  final int segmentIndex;
  final double progressMeters;
  final double distanceMeters;
  final GeoPoint point;
  final double score;
}
