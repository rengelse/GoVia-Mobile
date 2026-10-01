import 'dart:math' as math;

import '../../../domain/models.dart';

/// Geometry utilities used only for product metadata such as POI/waypoint distance.
/// Navigation progress, matching and maneuver advancement are owned by Ferrostar natively.
List<StageWaypoint> reprojectStageWaypoints(
  List<StageWaypoint> waypoints,
  List<GeoPoint> geometry,
) =>
    waypoints.map((waypoint) {
      final location = waypoint.location;
      if (location == null) return waypoint;
      final progress = routeProgressForPoint(
        location,
        geometry,
        expectedProgressMeters: waypoint.distanceFromStartMeters.toDouble(),
      );
      return StageWaypoint(
        id: waypoint.id,
        name: waypoint.name,
        kind: waypoint.kind,
        location: waypoint.location,
        category: waypoint.category,
        note: waypoint.note,
        distanceFromStartMeters: progress.round(),
      );
    }).toList(growable: false);

double routeProgressForPoint(
  GeoPoint point,
  List<GeoPoint> geometry, {
  double? expectedProgressMeters,
}) {
  if (geometry.length < 2) return 0;
  final cumulative = cumulativeDistances(geometry);
  var bestScore = double.infinity;
  var bestProgress = 0.0;
  final target = expectedProgressMeters != null && expectedProgressMeters > 0 ? expectedProgressMeters : null;
  for (var i = 0; i < geometry.length - 1; i++) {
    final projection = projectToSegment(point.lat, point.lon, geometry[i], geometry[i + 1]);
    final progress = cumulative[i] + projection.segmentMeters * projection.t;
    final targetPenalty = target == null ? 0.0 : math.min(250.0, (progress - target).abs() * .05);
    final score = projection.distanceMeters + targetPenalty;
    if (score < bestScore) {
      bestScore = score;
      bestProgress = progress;
    }
  }
  return bestProgress;
}

List<double> cumulativeDistances(List<GeoPoint> points) {
  if (points.isEmpty) return const [];
  final out = List<double>.filled(points.length, 0);
  for (var i = 1; i < points.length; i++) {
    out[i] = out[i - 1] + haversineMeters(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon);
  }
  return out;
}

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

class SegmentProjection {
  const SegmentProjection({
    required this.t,
    required this.distanceMeters,
    required this.segmentMeters,
  });

  final double t;
  final double distanceMeters;
  final double segmentMeters;
}

SegmentProjection projectToSegment(double lat, double lon, GeoPoint a, GeoPoint b) {
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
  final t = length2 <= 1e-14
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / length2).clamp(0.0, 1.0).toDouble();
  final snappedLat = a.lat + (b.lat - a.lat) * t;
  final snappedLon = a.lon + (b.lon - a.lon) * t;
  return SegmentProjection(
    t: t,
    distanceMeters: haversineMeters(lat, lon, snappedLat, snappedLon),
    segmentMeters: haversineMeters(a.lat, a.lon, b.lat, b.lon),
  );
}
