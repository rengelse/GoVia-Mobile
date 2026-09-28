import 'dart:math' as math;

import '../../../domain/models.dart';

class NavigationFix {
  const NavigationFix({
    required this.lat,
    required this.lon,
    required this.speedMetersPerSecond,
    required this.timestamp,
  });

  final double lat;
  final double lon;
  final double speedMetersPerSecond;
  final DateTime timestamp;
}

class NavigationProgress {
  const NavigationProgress({
    required this.progressMeters,
    required this.remainingMeters,
    required this.offRouteDistanceMeters,
    required this.remainingSeconds,
    required this.matchedPoint,
    required this.arrived,
  });

  final double progressMeters;
  final double remainingMeters;
  final double offRouteDistanceMeters;
  final int remainingSeconds;
  final GeoPoint? matchedPoint;
  final bool arrived;
}

/// UI-independent navigation progress/ETA core used by the phone navigator.
/// Android Auto mirrors the same contract in its native navigation service.
class GoViaNavigationEngine {
  GoViaNavigationEngine(RouteCandidate route) {
    setRoute(route);
  }

  late RouteCandidate _route;
  List<double> _cumulative = const [];
  double _progressMeters = 0;
  double? _smoothedMovingSpeed;
  DateTime? _firstFixAt;
  double _firstProgressMeters = 0;
  int _arrivalFixes = 0;

  RouteCandidate get route => _route;
  double get progressMeters => _progressMeters;

  void setRoute(RouteCandidate route) {
    _route = route;
    _cumulative = _cumulativeDistances(route.geometry);
    _progressMeters = 0;
    _smoothedMovingSpeed = null;
    _firstFixAt = null;
    _firstProgressMeters = 0;
    _arrivalFixes = 0;
  }

  NavigationProgress update(NavigationFix fix) {
    if (_route.geometry.length < 2 || _cumulative.length != _route.geometry.length) {
      return NavigationProgress(
        progressMeters: 0,
        remainingMeters: _route.distanceMeters.toDouble(),
        offRouteDistanceMeters: 0,
        remainingSeconds: _route.durationSeconds,
        matchedPoint: null,
        arrived: false,
      );
    }

    final projection = _nearestProjection(fix.lat, fix.lon);
    // Do not let noisy GPS move navigation substantially backwards.
    if (projection.progressMeters >= _progressMeters - 35) {
      _progressMeters = math.max(_progressMeters, projection.progressMeters);
    }

    _firstFixAt ??= fix.timestamp;
    if (_firstProgressMeters == 0) _firstProgressMeters = _progressMeters;

    final speed = fix.speedMetersPerSecond.isFinite
        ? fix.speedMetersPerSecond.clamp(0.0, 80.0).toDouble()
        : 0.0;
    if (speed >= 1.5) {
      _smoothedMovingSpeed = _smoothedMovingSpeed == null
          ? speed
          : (_smoothedMovingSpeed! * .82 + speed * .18);
    }

    final routeLength = _cumulative.last;
    final remaining = math.max(0.0, routeLength - _progressMeters);
    final destination = _route.geometry.last;
    final destinationDistance = _haversine(fix.lat, fix.lon, destination.lat, destination.lon);
    final credibleArrival = destinationDistance <= 25 || (destinationDistance <= 55 && speed <= 5);
    if (credibleArrival) {
      _arrivalFixes += 1;
    } else if (destinationDistance > 80) {
      _arrivalFixes = 0;
    }

    return NavigationProgress(
      progressMeters: _progressMeters,
      remainingMeters: remaining,
      offRouteDistanceMeters: projection.distanceMeters,
      remainingSeconds: _estimateRemainingSeconds(remaining, fix.timestamp),
      matchedPoint: projection.distanceMeters <= 140 ? projection.point : null,
      arrived: _arrivalFixes >= 3,
    );
  }

  int _estimateRemainingSeconds(double remainingMeters, DateTime now) {
    if (remainingMeters <= 0) return 0;
    final totalDistance = math.max(1.0, _cumulative.isEmpty ? _route.distanceMeters.toDouble() : _cumulative.last);
    final baselineSeconds = math.max(1, _route.durationSeconds);
    final baselineSpeed = totalDistance / baselineSeconds;

    double? observedSpeed;
    final first = _firstFixAt;
    if (first != null) {
      final elapsed = now.difference(first).inMilliseconds / 1000.0;
      final progressed = math.max(0.0, _progressMeters - _firstProgressMeters);
      if (elapsed >= 90 && progressed >= 500) observedSpeed = progressed / elapsed;
    }

    final movingSpeed = _smoothedMovingSpeed;
    var effectiveSpeed = baselineSpeed;
    if (observedSpeed != null && observedSpeed >= 1.5) {
      effectiveSpeed = baselineSpeed * .45 + observedSpeed * .55;
    }
    if (movingSpeed != null && movingSpeed >= 1.5) {
      effectiveSpeed = effectiveSpeed * .75 + movingSpeed * .25;
    }
    // Bound adaptation to avoid absurd ETA swings from temporary stops/GPS spikes.
    effectiveSpeed = effectiveSpeed.clamp(baselineSpeed * .45, baselineSpeed * 1.35).toDouble();
    return (remainingMeters / math.max(.8, effectiveSpeed)).round();
  }

  _Projection _nearestProjection(double lat, double lon) {
    var best = _Projection(
      progressMeters: 0,
      distanceMeters: double.infinity,
      point: _route.geometry.first,
    );
    for (var i = 0; i < _route.geometry.length - 1; i++) {
      final a = _route.geometry[i];
      final b = _route.geometry[i + 1];
      final projection = _project(lat, lon, a, b);
      final progress = _cumulative[i] + projection.segmentMeters * projection.t;
      if (projection.distanceMeters < best.distanceMeters) {
        best = _Projection(
          progressMeters: progress,
          distanceMeters: projection.distanceMeters,
          point: projection.point,
        );
      }
    }
    return best;
  }

  List<double> _cumulativeDistances(List<GeoPoint> points) {
    if (points.isEmpty) return const [];
    final out = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      out[i] = out[i - 1] + _haversine(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon);
    }
    return out;
  }

  _SegmentProjection _project(double lat, double lon, GeoPoint a, GeoPoint b) {
    final scale = math.cos(lat * math.pi / 180).clamp(.2, 1.0).toDouble();
    final ax = a.lon * scale;
    final ay = a.lat;
    final bx = b.lon * scale;
    final by = b.lat;
    final px = lon * scale;
    final py = lat;
    final dx = bx - ax;
    final dy = by - ay;
    final length2 = dx * dx + dy * dy;
    final t = length2 <= 1e-14 ? 0.0 : (((px - ax) * dx + (py - ay) * dy) / length2).clamp(0.0, 1.0).toDouble();
    final point = GeoPoint(lat: a.lat + (b.lat - a.lat) * t, lon: a.lon + (b.lon - a.lon) * t);
    return _SegmentProjection(
      t: t,
      point: point,
      distanceMeters: _haversine(lat, lon, point.lat, point.lon),
      segmentMeters: _haversine(a.lat, a.lon, b.lat, b.lon),
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _Projection {
  const _Projection({required this.progressMeters, required this.distanceMeters, required this.point});
  final double progressMeters;
  final double distanceMeters;
  final GeoPoint point;
}

class _SegmentProjection {
  const _SegmentProjection({required this.t, required this.distanceMeters, required this.segmentMeters, required this.point});
  final double t;
  final double distanceMeters;
  final double segmentMeters;
  final GeoPoint point;
}
