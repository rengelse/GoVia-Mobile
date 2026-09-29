class NavigationRerouteRequestIdentity {
  const NavigationRerouteRequestIdentity({
    required this.tripId,
    required this.stageId,
    required this.routeId,
    required this.sessionRevision,
  });

  final String tripId;
  final String stageId;
  final String routeId;
  final int sessionRevision;

  bool matches({
    required String currentTripId,
    required String currentStageId,
    required String currentRouteId,
    required int currentSessionRevision,
  }) =>
      tripId == currentTripId &&
      stageId == currentStageId &&
      routeId == currentRouteId &&
      sessionRevision == currentSessionRevision;
}
