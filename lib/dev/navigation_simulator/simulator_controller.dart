import 'dart:async';
import 'dart:math' as math;

import '../../domain/models.dart';
import '../../features/navigation/domain/navigation_location_sample.dart';
import 'simulator_models.dart';

class NavigationSimulatorController {
  NavigationSimulatorController(this.scenario) {
    _setRoute(_officialRoute(scenario.stage));
  }

  final NavigationSimulatorScenario scenario;
  final _stream = StreamController<NavigationLocationSample>.broadcast();
  Timer? _timer;
  RouteCandidate? _route;
  List<double> _cumulative = const [];
  double _progressMeters = 0;
  double _speedMultiplier = 1;
  bool _running = false;
  bool _gpsSuppressed = false;
  int _offRouteTicks = 0;
  int _jitterTicks = 0;
  int _stopTicks = 0;
  bool _stressGpsGapDone = false;
  bool _stressOffRouteDone = false;
  bool _stressJitterDone = false;
  bool _stressStopDone = false;

  Stream<NavigationLocationSample> get stream => _stream.stream;
  bool get running => _running;
  double get speedMultiplier => _speedMultiplier;
  double get progressMeters => _progressMeters;
  RouteCandidate get route => _route!;

  void start() {
    if (_running) return;
    _running = true;
    _timer ??= Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    _emitCurrent();
  }

  void pause() => _running = false;

  void resume() {
    _running = true;
    _emitCurrent();
  }

  void setSpeedMultiplier(double value) {
    _speedMultiplier = value.clamp(.25, 20).toDouble();
  }

  void jumpToNextManeuver() {
    final next = route.maneuvers.where((m) => m.distanceFromStartMeters > _progressMeters + 20).firstOrNull;
    if (next == null) return;
    _progressMeters = math.max(0, next.distanceFromStartMeters - 80).toDouble();
    _emitCurrent();
  }

  void injectOffRoute() {
    _offRouteTicks = 5;
    _running = true;
  }

  void injectGpsJitter() {
    _jitterTicks = 8;
    _running = true;
  }

  void injectGpsLoss({Duration duration = const Duration(seconds: 8)}) {
    _gpsSuppressed = true;
    Timer(duration, () {
      _gpsSuppressed = false;
      if (!_stream.isClosed) _emitCurrent();
    });
  }

  void injectStop({Duration duration = const Duration(seconds: 8)}) {
    _stopTicks = math.max(1, (duration.inMilliseconds / 500).round());
    _running = true;
  }

  void jumpToArrival() {
    _progressMeters = math.max(0, _cumulative.last - 3).toDouble();
    _running = true;
    _emitCurrent(speedOverride: 1.0);
  }


  void _tick() {
    if (!_running || _route == null || _gpsSuppressed) return;

    final fraction = _cumulative.last <= 0 ? 0.0 : _progressMeters / _cumulative.last;
    if (scenario.autoStress) {
      if (!_stressJitterDone && fraction >= .20) {
        _stressJitterDone = true;
        _jitterTicks = 8;
      }
      if (!_stressGpsGapDone && fraction >= .35) {
        _stressGpsGapDone = true;
        injectGpsLoss(duration: const Duration(seconds: 6));
        return;
      }
      if (!_stressStopDone && fraction >= .52) {
        _stressStopDone = true;
        _stopTicks = 14;
      }
      if (!_stressOffRouteDone && fraction >= .68) {
        _stressOffRouteDone = true;
        _offRouteTicks = 6;
      }
    }

    final baseSpeed = _stopTicks > 0
        ? 0.0
        : scenario.defaultSpeedMps * _speedMultiplier * (scenario.autoStress && fraction > .42 && fraction < .52 ? .22 : 1.0);
    if (_stopTicks > 0) _stopTicks--;

    _progressMeters = math.min(_cumulative.last, _progressMeters + baseSpeed * .5);
    _emitCurrent(speedOverride: baseSpeed);
    if (_progressMeters >= _cumulative.last) {
      _running = false;
    }
  }

  void _emitCurrent({double? speedOverride}) {
    if (_stream.isClosed || _route == null || _gpsSuppressed) return;
    final point = _pointAt(_progressMeters);
    final ahead = _pointAt(math.min(_cumulative.last, _progressMeters + 15));
    var lat = point.lat;
    var lon = point.lon;

    if (_offRouteTicks > 0) {
      _offRouteTicks--;
      lat += 0.00115; // ~128 m north: enough to cross the 85 m off-route gate.
      lon += 0.00055;
    } else if (_jitterTicks > 0) {
      final phase = _jitterTicks--;
      lat += (phase.isEven ? 1 : -1) * 0.00010;
      lon += (phase % 3 == 0 ? 1 : -1) * 0.00012;
    }

    _stream.add(NavigationLocationSample(
      latitude: lat,
      longitude: lon,
      speedMetersPerSecond: speedOverride ?? scenario.defaultSpeedMps * _speedMultiplier,
      heading: _bearing(point, ahead),
      timestamp: DateTime.now(),
      accuracyMeters: _jitterTicks > 0 ? 28 : 4,
    ));
  }

  void _setRoute(RouteCandidate route) {
    _route = route;
    _cumulative = <double>[0];
    for (var i = 1; i < route.geometry.length; i++) {
      _cumulative.add(_cumulative.last + _distance(route.geometry[i - 1], route.geometry[i]));
    }
  }

  GeoPoint _pointAt(double meters) {
    final points = route.geometry;
    if (meters <= 0) return points.first;
    if (meters >= _cumulative.last) return points.last;
    for (var i = 1; i < points.length; i++) {
      if (_cumulative[i] < meters) continue;
      final segment = _cumulative[i] - _cumulative[i - 1];
      final t = segment <= 0 ? 0.0 : (meters - _cumulative[i - 1]) / segment;
      return GeoPoint(
        lat: points[i - 1].lat + (points[i].lat - points[i - 1].lat) * t,
        lon: points[i - 1].lon + (points[i].lon - points[i - 1].lon) * t,
      );
    }
    return points.last;
  }

  void dispose() {
    _timer?.cancel();
    _stream.close();
  }
}

RouteCandidate _officialRoute(Stage stage) => stage.routeCandidates.firstWhere(
      (route) => route.id == stage.officialRouteId,
      orElse: () => stage.routeCandidates.first,
    );

double _routeLength(List<GeoPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _distance(points[i - 1], points[i]);
  }
  return total;
}

double _distance(GeoPoint a, GeoPoint b) {
  const radius = 6371000.0;
  final p1 = a.lat * math.pi / 180;
  final p2 = b.lat * math.pi / 180;
  final dp = (b.lat - a.lat) * math.pi / 180;
  final dl = (b.lon - a.lon) * math.pi / 180;
  final h = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * radius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _bearing(GeoPoint a, GeoPoint b) {
  final p1 = a.lat * math.pi / 180;
  final p2 = b.lat * math.pi / 180;
  final dl = (b.lon - a.lon) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
