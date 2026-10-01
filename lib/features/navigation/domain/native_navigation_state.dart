import '../../../domain/models.dart';

class NativeNavigationState {
  const NativeNavigationState({
    required this.stageId,
    required this.routeId,
    required this.navigating,
    required this.arrived,
    required this.progressMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.distanceToManeuverMeters,
    required this.snappedPosition,
    required this.currentManeuver,
    required this.nextManeuver,
    required this.speedLimitKph,
    required this.deviation,
    required this.rerouteRequired,
    required this.spokenInstructionId,
    required this.spokenInstructionText,
    required this.gpsQuality,
  });

  final String stageId;
  final String routeId;
  final bool navigating;
  final bool arrived;
  final double progressMeters;
  final double remainingMeters;
  final int remainingSeconds;
  final double? distanceToManeuverMeters;
  final GeoPoint? snappedPosition;
  final NavigationManeuver? currentManeuver;
  final NavigationManeuver? nextManeuver;
  final int? speedLimitKph;
  final String deviation;
  final bool rerouteRequired;
  final String? spokenInstructionId;
  final String? spokenInstructionText;
  final String gpsQuality;

  factory NativeNavigationState.fromMap(Map<dynamic, dynamic> json) {
    GeoPoint? point;
    final rawPoint = json['snappedPosition'];
    if (rawPoint is List && rawPoint.length >= 2 && rawPoint[0] is num && rawPoint[1] is num) {
      point = GeoPoint(lon: (rawPoint[0] as num).toDouble(), lat: (rawPoint[1] as num).toDouble());
    }
    final current = json['currentManeuver'];
    final next = json['nextManeuver'];
    return NativeNavigationState(
      stageId: json['stageId']?.toString() ?? '',
      routeId: json['routeId']?.toString() ?? '',
      navigating: json['navigating'] == true,
      arrived: json['arrived'] == true,
      progressMeters: (json['progressMeters'] as num? ?? 0).toDouble(),
      remainingMeters: (json['remainingMeters'] as num? ?? 0).toDouble(),
      remainingSeconds: (json['remainingSeconds'] as num? ?? 0).round(),
      distanceToManeuverMeters: (json['distanceToManeuverMeters'] as num?)?.toDouble(),
      snappedPosition: point,
      currentManeuver: current is Map ? NavigationManeuver.fromRuntimeJson(current) : null,
      nextManeuver: next is Map ? NavigationManeuver.fromRuntimeJson(next) : null,
      speedLimitKph: (json['speedLimitKph'] as num?)?.round(),
      deviation: json['deviation']?.toString() ?? 'idle',
      rerouteRequired: json['rerouteRequired'] == true,
      spokenInstructionId: json['spokenInstructionId']?.toString(),
      spokenInstructionText: json['spokenInstructionText']?.toString(),
      gpsQuality: json['gpsQuality']?.toString() ?? 'unknown',
    );
  }
}
