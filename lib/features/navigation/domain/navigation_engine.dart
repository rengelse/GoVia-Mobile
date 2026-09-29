import '../../../domain/models.dart';
import 'navigation_route.dart';
import 'navigation_session.dart' as v2;

/// Compatibility facade for older call sites/tests.
/// Navigation Core v2 is implemented by [v2.NavigationSession].
class NavigationFix extends v2.NavigationFix {
  const NavigationFix({
    required super.lat,
    required super.lon,
    required super.speedMetersPerSecond,
    required super.timestamp,
    super.headingDegrees,
    super.accuracyMeters = 10,
  });
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

class GoViaNavigationEngine {
  GoViaNavigationEngine(RouteCandidate route)
      : _stage = Stage(
          id: 'legacy-navigation-stage',
          day: 0,
          order: 0,
          start: route.geometry.firstOrNull?.label ?? 'Start',
          end: route.geometry.lastOrNull?.label ?? 'Mål',
          transport: StageTransport.car,
          routeCandidates: [route],
          officialRouteId: route.id,
        ) {
    setRoute(route);
  }

  final Stage _stage;
  late v2.NavigationSession _session;
  late RouteCandidate _route;

  RouteCandidate get route => _route;
  double get progressMeters => _session.state?.progressMeters ?? 0;

  void setRoute(RouteCandidate route) {
    _route = route;
    _session = v2.NavigationSession(NavigationRoute.fromStage(_stage, route));
  }

  NavigationProgress update(NavigationFix fix) {
    final state = _session.update(fix);
    return NavigationProgress(
      progressMeters: state.progressMeters,
      remainingMeters: state.remainingMeters,
      offRouteDistanceMeters: state.offRouteDistanceMeters,
      remainingSeconds: state.remainingSeconds,
      matchedPoint: state.matchedPoint,
      arrived: state.arrived,
    );
  }
}
