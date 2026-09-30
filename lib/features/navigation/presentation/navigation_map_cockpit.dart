import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/govia_theme.dart';
import '../../../domain/models.dart';

enum NavigationMapViewMode { perspective, northUp, overview }

extension NavigationMapViewModeX on NavigationMapViewMode {
  NavigationMapViewMode get next => switch (this) {
        NavigationMapViewMode.perspective => NavigationMapViewMode.northUp,
        NavigationMapViewMode.northUp => NavigationMapViewMode.overview,
        NavigationMapViewMode.overview => NavigationMapViewMode.perspective,
      };

  String get label => switch (this) {
        NavigationMapViewMode.perspective => 'Følg',
        NavigationMapViewMode.northUp => 'Nord opp',
        NavigationMapViewMode.overview => 'Oversikt',
      };

  IconData get icon => switch (this) {
        NavigationMapViewMode.perspective => Icons.navigation_rounded,
        NavigationMapViewMode.northUp => Icons.explore_rounded,
        NavigationMapViewMode.overview => Icons.map_rounded,
      };
}

class NavigationMapCockpit extends StatefulWidget {
  const NavigationMapCockpit({
    super.key,
    required this.geometry,
    this.position,
    this.matchedPoint,
    this.heading = 0,
    this.speedMetersPerSecond = 0,
    this.distanceToNextManeuver,
    this.controlsBottomInset = 14,
  });

  final List<GeoPoint> geometry;
  final GeoPoint? position;
  final GeoPoint? matchedPoint;
  final double heading;
  final double speedMetersPerSecond;
  final double? distanceToNextManeuver;
  final double controlsBottomInset;

  @override
  State<NavigationMapCockpit> createState() => _NavigationMapCockpitState();
}

class _NavigationMapCockpitState extends State<NavigationMapCockpit> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  Line? _routeLine;
  Circle? _positionCircle;
  Circle? _accuracyCircle;
  Timer? _motionTimer;
  GeoPoint? _visualPoint;
  GeoPoint? _motionTarget;
  int _motionTick = 0;
  GeoPoint? _smoothedCameraPoint;
  double? _smoothedBearing;
  double? _smoothedZoom;
  NavigationMapViewMode _mapViewMode = NavigationMapViewMode.perspective;

  @override
  void didUpdateWidget(covariant NavigationMapCockpit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry) {
      _redrawRoute();
    }
    if (oldWidget.position != widget.position || oldWidget.matchedPoint != widget.matchedPoint) {
      _setMotionTarget(widget.matchedPoint ?? widget.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.geometry;
    final initial = route.isNotEmpty
        ? LatLng(route.first.lat, route.first.lon)
        : const LatLng(58.6, 7.2);
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          styleString: 'https://tiles.openfreemap.org/styles/liberty',
          initialCameraPosition: CameraPosition(target: initial, zoom: 15, tilt: 52),
          compassEnabled: false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          onMapCreated: (controller) {
            _controller = controller;
            _syncMap();
          },
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            _syncMap();
          },
        ),
        Positioned(
          right: 12,
          bottom: widget.controlsBottomInset,
          child: FloatingActionButton.small(
            heroTag: 'nav-map-view-mode',
            tooltip: '${_mapViewMode.label} · trykk for neste kartvisning',
            backgroundColor: GoViaColors.panel,
            onPressed: _cycleMapViewMode,
            child: Icon(_mapViewMode.icon, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _syncMap() async {
    if (_controller == null || !_styleLoaded) return;
    await _redrawRoute();
    final point = widget.matchedPoint ?? widget.position;
    if (point != null) {
      _visualPoint = point;
      _motionTarget = point;
      _setMotionTarget(point);
    }
    await _updatePositionMarker(pointOverride: point);
    await _applyMapViewMode(force: true);
  }

  Future<void> _redrawRoute() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    if (_routeLine != null) {
      try {
        await controller.removeLine(_routeLine!);
      } catch (_) {}
      _routeLine = null;
    }
    final line = widget.geometry.map((point) => LatLng(point.lat, point.lon)).toList(growable: false);
    if (line.length < 2) return;
    _routeLine = await controller.addLine(
      LineOptions(
        geometry: line,
        lineColor: '#FF7A21',
        lineWidth: 7,
        lineOpacity: .98,
      ),
    );
  }

  Future<void> _updatePositionMarker({GeoPoint? pointOverride}) async {
    final controller = _controller;
    final point = pointOverride ?? _visualPoint ?? widget.matchedPoint ?? widget.position;
    if (controller == null || !_styleLoaded || point == null) return;
    final geometry = LatLng(point.lat, point.lon);

    if (_accuracyCircle == null) {
      _accuracyCircle = await controller.addCircle(
        CircleOptions(
          geometry: geometry,
          circleColor: '#2DD4FF',
          circleOpacity: .16,
          circleRadius: 18,
          circleStrokeWidth: 0,
        ),
      );
    } else {
      await controller.updateCircle(_accuracyCircle!, CircleOptions(geometry: geometry));
    }

    if (_positionCircle == null) {
      _positionCircle = await controller.addCircle(
        CircleOptions(
          geometry: geometry,
          circleColor: '#2DD4FF',
          circleRadius: 8,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    } else {
      await controller.updateCircle(_positionCircle!, CircleOptions(geometry: geometry));
    }
  }


  void _setMotionTarget(GeoPoint? target) {
    if (target == null) return;
    _motionTarget = target;
    _visualPoint ??= target;
    _motionTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      final destination = _motionTarget;
      final current = _visualPoint;
      if (destination == null || current == null || !_styleLoaded) return;
      final latDelta = (destination.lat - current.lat).abs();
      final lonDelta = (destination.lon - current.lon).abs();
      if (latDelta < 0.0000005 && lonDelta < 0.0000005) {
        _visualPoint = destination;
        unawaited(_updatePositionMarker(pointOverride: _visualPoint));
        if (_mapViewMode != NavigationMapViewMode.overview) unawaited(_followCamera());
        _motionTimer?.cancel();
        _motionTimer = null;
        return;
      }
      _visualPoint = _smoothPoint(current, destination, 0.30);
      unawaited(_updatePositionMarker(pointOverride: _visualPoint));
      _motionTick += 1;
      if (_mapViewMode != NavigationMapViewMode.overview && _motionTick % 3 == 0) {
        unawaited(_followCamera());
      }
    });
  }

  Future<void> _followCamera({bool force = false}) async {
    final controller = _controller;
    final point = _visualPoint ?? widget.matchedPoint ?? widget.position;
    if (controller == null || !_styleLoaded || point == null) return;
    if (_mapViewMode == NavigationMapViewMode.overview && !force) return;

    final speedKmh = widget.speedMetersPerSecond * 3.6;
    final maneuverDistance = widget.distanceToNextManeuver ?? double.infinity;
    final zoom = maneuverDistance < 120
        ? 17.2
        : maneuverDistance < 400
            ? 16.3
            : speedKmh >= 90
                ? 14.3
                : speedKmh >= 55
                    ? 14.9
                    : 15.6;
    final lookAheadMeters = maneuverDistance < 120
        ? 65.0
        : speedKmh >= 90
            ? 260.0
            : speedKmh >= 55
                ? 180.0
                : 110.0;
    final isNorthUp = _mapViewMode == NavigationMapViewMode.northUp;
    final effectiveLookAheadMeters = isNorthUp ? 0.0 : lookAheadMeters;
    final rawTarget = _project(point, widget.heading, effectiveLookAheadMeters);
    final target = force ? rawTarget : _smoothPoint(_smoothedCameraPoint, rawTarget, 0.58);
    final rawBearing = widget.heading.isFinite ? widget.heading : 0.0;
    final followBearing = force ? rawBearing : _smoothBearing(_smoothedBearing, rawBearing, 0.42);
    final bearing = isNorthUp ? 0.0 : followBearing;
    final smoothZoom = force ? zoom : _lerp(_smoothedZoom ?? zoom, zoom, 0.34);
    _smoothedCameraPoint = target;
    _smoothedBearing = bearing;
    _smoothedZoom = smoothZoom;
    await controller.easeCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(target.lat, target.lon),
          zoom: smoothZoom,
          tilt: isNorthUp ? 0 : 55,
          bearing: bearing,
        ),
      ),
      duration: force ? const Duration(milliseconds: 300) : const Duration(milliseconds: 450),
      interpolation: CameraAnimationInterpolation.linear,
    );
  }



  void _cycleMapViewMode() {
    final next = _mapViewMode.next;
    setState(() => _mapViewMode = next);
    unawaited(_applyMapViewMode(force: true));
  }

  Future<void> _applyMapViewMode({bool force = false}) async {
    if (_mapViewMode == NavigationMapViewMode.overview) {
      await _showRouteOverview();
      return;
    }
    await _followCamera(force: force);
  }

  Future<void> _showRouteOverview() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || widget.geometry.length < 2) return;
    var minLat = widget.geometry.first.lat;
    var maxLat = minLat;
    var minLon = widget.geometry.first.lon;
    var maxLon = minLon;
    for (final point in widget.geometry.skip(1)) {
      minLat = math.min(minLat, point.lat);
      maxLat = math.max(maxLat, point.lat);
      minLon = math.min(minLon, point.lon);
      maxLon = math.max(maxLon, point.lon);
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        left: 52,
        top: 110,
        right: 52,
        bottom: widget.controlsBottomInset + 90,
      ),
    );
  }

  GeoPoint _smoothPoint(GeoPoint? from, GeoPoint to, double factor) {
    if (from == null) return to;
    return GeoPoint(
      lat: _lerp(from.lat, to.lat, factor),
      lon: _lerp(from.lon, to.lon, factor),
    );
  }

  double _smoothBearing(double? from, double to, double factor) {
    if (from == null) return _normalizeBearing(to);
    final start = _normalizeBearing(from);
    final end = _normalizeBearing(to);
    var delta = end - start;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return _normalizeBearing(start + delta * factor);
  }

  double _normalizeBearing(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double _lerp(double from, double to, double factor) => from + (to - from) * factor;


  @override
  void dispose() {
    _motionTimer?.cancel();
    _motionTimer = null;
    super.dispose();
  }

  GeoPoint _project(GeoPoint start, double bearingDegrees, double meters) {
    const earthRadius = 6371000.0;
    final bearing = bearingDegrees * math.pi / 180;
    final lat1 = start.lat * math.pi / 180;
    final lon1 = start.lon * math.pi / 180;
    final angular = meters / earthRadius;
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angular) +
          math.cos(lat1) * math.sin(angular) * math.cos(bearing),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(lat1),
          math.cos(angular) - math.sin(lat1) * math.sin(lat2),
        );
    return GeoPoint(lat: lat2 * 180 / math.pi, lon: lon2 * 180 / math.pi);
  }
}
