import '../../domain/models.dart';

/// Stable identity for the rendered route surface.
///
/// The map surface must be remounted whenever route geometry or visible
/// waypoints change. Keeping this pure makes the behaviour directly testable
/// without depending on MapLibre widget internals.
String routeRenderKey(
  List<GeoPoint> points,
  List<StageWaypoint> waypoints,
  bool connectPoints,
  bool showRiders,
) =>
    '${connectPoints ? 1 : 0}|${showRiders ? 1 : 0}|${points.map((p) => '${p.lat.toStringAsFixed(6)},${p.lon.toStringAsFixed(6)}').join(';')}|${waypoints.where((w) => w.location != null).map((w) => '${w.kind.name}:${w.location!.lat.toStringAsFixed(6)},${w.location!.lon.toStringAsFixed(6)}').join(';')}';
