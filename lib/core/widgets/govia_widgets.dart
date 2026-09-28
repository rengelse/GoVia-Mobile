import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../theme/govia_theme.dart';
import '../../domain/models.dart';
import '../map/route_render_key.dart';

class GoViaLogo extends StatelessWidget {
  const GoViaLogo({super.key, this.compact = false});
  static const assetPath = 'assets/brand/govia-logo-horizontal.png';
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'GoVia',
        image: true,
        child: Image.asset(
          assetPath,
          height: compact ? 34 : 48,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)), if (trailing != null) trailing!]),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.color = GoViaColors.blue, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .45))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 5)], Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))]),
      );
}

class RouteMapCard extends StatelessWidget {
  const RouteMapCard({super.key, this.height = 210, this.points = const [], this.waypoints = const [], this.showRiders = false, this.label, this.connectPoints = true});
  final double height;
  final List<GeoPoint> points;
  final List<StageWaypoint> waypoints;
  final bool showRiders;
  final String? label;
  final bool connectPoints;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MapLibreSurface(key: ValueKey(routeRenderKey(points, waypoints, connectPoints, showRiders)), points: points, waypoints: waypoints, showRiders: showRiders, connectPoints: connectPoints),
              Positioned(top: 12, left: 12, child: StatusPill(label ?? 'Rute', color: GoViaColors.cyan, icon: Icons.route)),
            ],
          ),
        ),
      );
}

class _MapLibreSurface extends StatefulWidget {
  const _MapLibreSurface({super.key, required this.points, required this.waypoints, required this.showRiders, required this.connectPoints});
  final List<GeoPoint> points;
  final List<StageWaypoint> waypoints;
  final bool showRiders;
  final bool connectPoints;
  @override State<_MapLibreSurface> createState() => _MapLibreSurfaceState();
}

class _MapLibreSurfaceState extends State<_MapLibreSurface> {
  MapLibreMapController? controller;
  bool styleLoaded = false;
  bool annotationsDrawn = false;

  List<LatLng> get route => widget.points.map((p) => LatLng(p.lat, p.lon)).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final initial = route.isNotEmpty ? route.first : const LatLng(58.6, 7.2);
    return MapLibreMap(
      styleString: 'https://tiles.openfreemap.org/styles/liberty',
      initialCameraPosition: CameraPosition(target: initial, zoom: route.length > 1 ? 7 : 5.5),
      compassEnabled: false,
      onMapCreated: (value) {
        controller = value;
        _draw();
      },
      onStyleLoadedCallback: () {
        styleLoaded = true;
        _draw();
      },
    );
  }

  Future<void> _draw() async {
    final c = controller;
    if (c == null || !styleLoaded || annotationsDrawn) return;
    annotationsDrawn = true;
    final line = route;
    if (line.length > 1 && widget.connectPoints) {
      await c.addLine(LineOptions(geometry: line, lineColor: '#FF7A21', lineWidth: 5, lineOpacity: .95));
      final minLat = line.map((p) => p.latitude).reduce(math.min);
      final maxLat = line.map((p) => p.latitude).reduce(math.max);
      final minLon = line.map((p) => p.longitude).reduce(math.min);
      final maxLon = line.map((p) => p.longitude).reduce(math.max);
      await c.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)),
        left: 34,
        top: 34,
        right: 34,
        bottom: 34,
      ));
    }
    // Route geometry may contain hundreds or thousands of coordinates. Those
    // coordinates are not waypoints and must never receive a marker each.
    // Doing so creates overlapping white marker strokes that look like an
    // eraser drawn across the route. For a connected route we only mark the
    // endpoints. For an unconnected point preview (start/via/end) every point
    // is a real waypoint and may be marked.
    final markerIndexes = widget.connectPoints && line.length > 1
        ? <int>{0, line.length - 1}
        : <int>{for (var i = 0; i < line.length; i++) i};
    for (final i in markerIndexes) {
      final color = i == 0 ? '#49DF8B' : (i == line.length - 1 ? '#FF7A21' : '#2DD4FF');
      await c.addCircle(CircleOptions(
        geometry: line[i],
        circleColor: color,
        circleRadius: i == 0 || i == line.length - 1 ? 7 : 5,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ));
    }
    if (line.length > 1 && !widget.connectPoints) {
      final minLat = line.map((p) => p.latitude).reduce(math.min);
      final maxLat = line.map((p) => p.latitude).reduce(math.max);
      final minLon = line.map((p) => p.longitude).reduce(math.min);
      final maxLon = line.map((p) => p.longitude).reduce(math.max);
      await c.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)),
        left: 34,
        top: 34,
        right: 34,
        bottom: 34,
      ));
    }
    for (final waypoint in widget.waypoints) {
      final point = waypoint.location;
      if (point == null) continue;
      final color = switch (waypoint.kind) {
        StageWaypointKind.poi => '#2DD4FF',
        StageWaypointKind.stop => '#FFB020',
        StageWaypointKind.via => '#A78BFA',
      };
      await c.addCircle(CircleOptions(
        geometry: LatLng(point.lat, point.lon),
        circleColor: color,
        circleRadius: waypoint.kind == StageWaypointKind.poi ? 6 : 7,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ));
    }
    if (widget.showRiders) {
      final center = line.isNotEmpty ? line[line.length ~/ 2] : const LatLng(58.6, 7.2);
      final riders = [
        center,
        LatLng(center.latitude + .035, center.longitude + .045),
        LatLng(center.latitude - .028, center.longitude - .035),
      ];
      for (final rider in riders) {
        await c.addCircle(CircleOptions(
          geometry: rider,
          circleColor: '#2DD4FF',
          circleRadius: 7,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ));
      }
    }
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.icon, this.color = GoViaColors.blue});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GoViaColors.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: GoViaColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 19), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: GoViaColors.muted, fontSize: 12))]),
        ),
      );
}
