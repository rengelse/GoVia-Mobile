import 'dart:math' as math;

import '../../../domain/models.dart';

class NavigationRouteManeuver {
  const NavigationRouteManeuver({
    required this.maneuver,
    required this.shapeIndex,
    required this.routeProgressMeters,
  });

  final NavigationManeuver maneuver;
  final int shapeIndex;
  final double routeProgressMeters;
}

/// Canonical route used by Navigation Core v2.
///
/// Maneuvers are anchored to the route geometry once when the route is created.
/// Runtime progression therefore does not depend on backend distanceFromStart values
/// staying perfectly aligned with locally measured geometry length.
class NavigationRoute {
  const NavigationRoute({
    required this.stageId,
    required this.routeId,
    required this.name,
    required this.geometry,
    required this.maneuvers,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.guidanceSource,
    required this.transport,
    required this.routeProfile,
    required this.routePreferences,
    required this.destinationName,
  });

  final String stageId;
  final String routeId;
  final String name;
  final List<GeoPoint> geometry;
  final List<NavigationRouteManeuver> maneuvers;
  final int distanceMeters;
  final int durationSeconds;
  final String guidanceSource;
  final StageTransport transport;
  final String routeProfile;
  final RoutePreferences routePreferences;
  final String destinationName;

  bool get guidanceReady => geometry.length >= 2 && maneuvers.isNotEmpty;

  factory NavigationRoute.fromStage(Stage stage, RouteCandidate candidate) {
    final cumulative = cumulativeDistances(candidate.geometry);
    var previousShapeIndex = 0;
    var previousProgressMeters = 0.0;
    final anchored = <NavigationRouteManeuver>[];
    for (final maneuver in [...candidate.maneuvers]..sort((a, b) => a.sequence.compareTo(b.sequence))) {
      final anchor = _nearestRouteAnchor(
        maneuver.location,
        candidate.geometry,
        cumulative,
        startIndex: previousShapeIndex,
        minimumProgressMeters: previousProgressMeters,
        expectedProgressMeters: maneuver.distanceFromStartMeters.toDouble(),
      );
      previousShapeIndex = math.max(previousShapeIndex, anchor.shapeIndex);
      previousProgressMeters = math.max(previousProgressMeters, anchor.progressMeters);
      anchored.add(NavigationRouteManeuver(
        maneuver: maneuver,
        shapeIndex: anchor.shapeIndex,
        routeProgressMeters: anchor.progressMeters,
      ));
    }
    return NavigationRoute(
      stageId: stage.id,
      routeId: candidate.id,
      name: candidate.name,
      geometry: List<GeoPoint>.unmodifiable(candidate.geometry),
      maneuvers: List<NavigationRouteManeuver>.unmodifiable(anchored),
      distanceMeters: candidate.distanceMeters,
      durationSeconds: candidate.durationSeconds,
      guidanceSource: candidate.guidanceSource,
      transport: stage.transport,
      routeProfile: stage.routeProfile,
      routePreferences: stage.routePreferences,
      destinationName: stage.end,
    );
  }

  RouteCandidate toRouteCandidate({bool official = true}) => RouteCandidate(
        id: routeId,
        name: name,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        geometry: geometry,
        maneuvers: maneuvers.map((item) => item.maneuver).toList(growable: false),
        guidanceSource: guidanceSource,
        official: official,
      );
}


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

class RouteAnchor {
  const RouteAnchor({required this.shapeIndex, required this.progressMeters});
  final int shapeIndex;
  final double progressMeters;
}

RouteAnchor _nearestRouteAnchor(
  GeoPoint point,
  List<GeoPoint> geometry,
  List<double> cumulative, {
  int startIndex = 0,
  double minimumProgressMeters = 0,
  double? expectedProgressMeters,
}) {
  if (geometry.length < 2 || cumulative.length != geometry.length) {
    return const RouteAnchor(shapeIndex: 0, progressMeters: 0);
  }
  var bestIndex = startIndex.clamp(0, geometry.length - 2);
  var bestProgress = math.max(minimumProgressMeters, cumulative[bestIndex]);
  var bestScore = double.infinity;
  final backendTarget = expectedProgressMeters != null && expectedProgressMeters > 0 ? expectedProgressMeters : null;
  for (var i = bestIndex; i < geometry.length - 1; i++) {
    final projection = projectToSegment(point.lat, point.lon, geometry[i], geometry[i + 1]);
    final progress = cumulative[i] + projection.segmentMeters * projection.t;
    if (progress + 1 < minimumProgressMeters) continue;
    final orderPenalty = math.max(0.0, minimumProgressMeters - progress) * 5;
    final targetPenalty = backendTarget == null ? 0.0 : math.min(250.0, (progress - backendTarget).abs() * .05);
    final score = projection.distanceMeters + orderPenalty + targetPenalty;
    if (score < bestScore || ((score - bestScore).abs() < .01 && progress > bestProgress)) {
      bestScore = score;
      bestIndex = i;
      bestProgress = progress;
    }
  }
  return RouteAnchor(shapeIndex: bestIndex, progressMeters: math.max(minimumProgressMeters, bestProgress));
}

class SegmentProjection {
  const SegmentProjection({
    required this.t,
    required this.distanceMeters,
    required this.segmentMeters,
    required this.point,
  });

  final double t;
  final double distanceMeters;
  final double segmentMeters;
  final GeoPoint point;
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
  final point = GeoPoint(
    lat: a.lat + (b.lat - a.lat) * t,
    lon: a.lon + (b.lon - a.lon) * t,
  );
  return SegmentProjection(
    t: t,
    point: point,
    distanceMeters: haversineMeters(lat, lon, point.lat, point.lon),
    segmentMeters: haversineMeters(a.lat, a.lon, b.lat, b.lon),
  );
}

double bearingDegrees(GeoPoint from, GeoPoint to) {
  final lat1 = from.lat * math.pi / 180;
  final lat2 = to.lat * math.pi / 180;
  final dLon = (to.lon - from.lon) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double headingDeltaDegrees(double a, double b) {
  final delta = ((a - b + 540) % 360) - 180;
  return delta.abs().toDouble();
}
