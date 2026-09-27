import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/govia_theme.dart';
import '../../../domain/models.dart';

class NavigationMapCockpit extends StatefulWidget {
  const NavigationMapCockpit({
    super.key,
    required this.geometry,
    this.position,
    this.matchedPoint,
    this.heading = 0,
    this.speedMetersPerSecond = 0,
    this.distanceToNextManeuver,
    this.followUser = true,
    this.onFollowChanged,
  });

  final List<GeoPoint> geometry;
  final GeoPoint? position;
  final GeoPoint? matchedPoint;
  final double heading;
  final double speedMetersPerSecond;
  final double? distanceToNextManeuver;
  final bool followUser;
  final ValueChanged<bool>? onFollowChanged;

  @override
  State<NavigationMapCockpit> createState() => _NavigationMapCockpitState();
}

class _NavigationMapCockpitState extends State<NavigationMapCockpit> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  Line? _routeLine;
  Circle? _positionCircle;
  Circle? _accuracyCircle;

  @override
  void didUpdateWidget(covariant NavigationMapCockpit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry) {
      _redrawRoute();
    }
    if (oldWidget.position != widget.position || oldWidget.matchedPoint != widget.matchedPoint) {
      _updatePositionMarker();
    }
    if (widget.followUser &&
        (oldWidget.position != widget.position ||
            oldWidget.heading != widget.heading ||
            oldWidget.speedMetersPerSecond != widget.speedMetersPerSecond ||
            oldWidget.distanceToNextManeuver != widget.distanceToNextManeuver ||
            !oldWidget.followUser)) {
      _followCamera();
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
          bottom: 14,
          child: FloatingActionButton.small(
            heroTag: 'nav-recenter',
            tooltip: widget.followUser ? 'Frikoble kamera' : 'Sentrer på meg',
            backgroundColor: widget.followUser ? GoViaColors.orange : GoViaColors.panel,
            onPressed: () {
              final next = !widget.followUser;
              widget.onFollowChanged?.call(next);
              if (next) _followCamera(force: true);
            },
            child: Icon(
              widget.followUser ? Icons.navigation_rounded : Icons.my_location_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _syncMap() async {
    if (_controller == null || !_styleLoaded) return;
    await _redrawRoute();
    await _updatePositionMarker();
    await _followCamera(force: true);
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

  Future<void> _updatePositionMarker() async {
    final controller = _controller;
    final point = widget.matchedPoint ?? widget.position;
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

  Future<void> _followCamera({bool force = false}) async {
    final controller = _controller;
    final point = widget.matchedPoint ?? widget.position;
    if (controller == null || !_styleLoaded || point == null) return;
    if (!widget.followUser && !force) return;

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
    final target = _project(point, widget.heading, lookAheadMeters);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(target.lat, target.lon),
          zoom: zoom,
          tilt: 55,
          bearing: widget.heading.isFinite ? widget.heading : 0,
        ),
      )
    );
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
