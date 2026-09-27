import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/domain/transport_profiles.dart';

void main() {
  test('ferry is an embedded segment, not a primary trip mode', () {
    expect(primaryTripTransports, isNot(contains(StageTransport.ferry)));
    expect(roundTripTransports, isNot(contains(StageTransport.ferry)));
    expect(primaryTripTransports, contains(StageTransport.train));
    expect(roundTripTransports, isNot(contains(StageTransport.train)));
  });

  test('roundtrip uses real backend contract', () {
    final screen = File('lib/features/new_trip/presentation/round_trip_screen.dart').readAsStringSync();
    expect(screen, contains("'/api/v1/map/roundtrip'"));
    expect(screen, isNot(contains('Backendkontrakt mangler')));
    expect(screen, contains('targetDistanceMeters'));
  });

  test('start pin can use current device position', () {
    final plan = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();
    expect(plan, contains('onUseCurrentLocation: _useCurrentLocation'));
    expect(plan, contains('Geolocator.getCurrentPosition'));
    expect(plan, contains("tooltip: 'Bruk min posisjon'"));
  });

  test('chat exposes like edit and delete through domain repository', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final screen = File('lib/features/chat/presentation/chat_screen.dart').readAsStringSync();
    expect(state, contains("'addReaction'"));
    expect(state, contains("'removeReaction'"));
    expect(state, contains("'editMessage'"));
    expect(state, contains("'deleteMessage'"));
    expect(screen, contains("value: 'edit'"));
    expect(screen, contains("value: 'delete'"));
    expect(screen, contains('Icons.favorite'));
  });

  test('community route publishing supports image uploads', () {
    final publish = File('lib/features/discover/presentation/publish_route_screen.dart').readAsStringSync();
    final auth = File('lib/features/auth/auth_service.dart').readAsStringSync();
    expect(publish, contains('pickMultiImage'));
    expect(publish, contains('uploadPublishedRoutePhoto'));
    expect(auth, contains("storage.from('published-route-media').uploadBinary"));
  });

  test('train routing stays on the rail backend', () {
    expect(routeModeForTransport(StageTransport.train), 'rail');
  });
}
