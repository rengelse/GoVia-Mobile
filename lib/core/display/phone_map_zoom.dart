// A display policy only: no route progress, matching or guidance calculations.
double phoneMapZoom({required bool automatic, required double currentZoom,
  required double speedMetersPerSecond, double? maneuverDistance}) {
  if (!automatic) { return currentZoom; }
  final speed = speedMetersPerSecond.isFinite && speedMetersPerSecond >= 0 ? speedMetersPerSecond * 3.6 : 0.0;
  final distance = maneuverDistance ?? double.infinity;
  return distance < 120 ? 17.2 : distance < 400 ? 16.3 : speed >= 90 ? 14.3 : speed >= 55 ? 14.9 : 15.6;
}

String phoneSpeedLabel(double? speedMetersPerSecond, {bool imperial = false}) {
  if (speedMetersPerSecond == null) { return 'Venter'; }
  if (!speedMetersPerSecond.isFinite || speedMetersPerSecond < 0) { return 'Ukjent'; }
  final speed = speedMetersPerSecond * (imperial ? 2.2369362921 : 3.6);
  return '${speed.round()} ${imperial ? 'mph' : 'km/t'}';
}
