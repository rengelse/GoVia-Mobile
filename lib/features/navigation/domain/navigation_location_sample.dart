class NavigationLocationSample {
  const NavigationLocationSample({
    required this.latitude,
    required this.longitude,
    required this.speedMetersPerSecond,
    required this.heading,
    required this.timestamp,
    this.accuracyMeters = 5,
  });

  final double latitude;
  final double longitude;
  final double speedMetersPerSecond;
  final double heading;
  final DateTime timestamp;
  final double accuracyMeters;
}
