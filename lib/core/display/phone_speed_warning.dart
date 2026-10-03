// Compare unrounded SI values; presentation units never change the threshold.
bool phoneSpeedWarning({required bool enabled, required bool navigating,
  required String gpsQuality, required double? speedMetersPerSecond,
  required int? speedLimitKph, required DateTime? sampleTime,
  required DateTime now, required double? accuracyMeters}) {
  if (!enabled || !navigating || gpsQuality.toLowerCase() != 'good' ||
      speedMetersPerSecond == null || !speedMetersPerSecond.isFinite ||
      speedMetersPerSecond < 0 || speedLimitKph == null || speedLimitKph <= 0) {
    return false;
  }
  if (sampleTime == null || accuracyMeters == null || !accuracyMeters.isFinite ||
      accuracyMeters < 0 || accuracyMeters > 25) {
    return false;
  }
  final age = now.difference(sampleTime);
  if (age.isNegative || age > const Duration(seconds: 10)) { return false; }
  return speedMetersPerSecond * 3.6 > speedLimitKph;
}
