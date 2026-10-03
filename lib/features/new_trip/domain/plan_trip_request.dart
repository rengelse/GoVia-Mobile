import '../../../domain/models.dart';

class PlanTripRequest {
  const PlanTripRequest({this.destination, this.destinationLabel, this.transport});
  final GeoPoint? destination;
  final String? destinationLabel;
  final StageTransport? transport;

  StageTransport resolveTransport(StageTransport? preferred) {
    final chosen = transport ?? preferred ?? StageTransport.car;
    return chosen == StageTransport.ferry ? StageTransport.car : chosen;
  }
}
