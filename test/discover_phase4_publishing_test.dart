import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase 4 publishing flow is wired end to end', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final publish = File('lib/features/discover/presentation/publish_route_screen.dart').readAsStringSync();
    final mine = File('lib/features/discover/presentation/my_published_routes_screen.dart').readAsStringSync();
    final routes = File('lib/app/app_routes.dart').readAsStringSync();

    expect(state, contains("api.domain('publishedRoute', 'listMine'"));
    expect(state, contains("api.domain('publishedRoute', 'update'"));
    expect(state, contains("api.domain('publishedRoute', 'archive'"));
    expect(state, contains("api.domain('publishedRoute', 'delete'"));
    expect(state, contains("api.domain('publishedRoute', 'setCoverPhoto'"));
    expect(publish, contains('Forhåndsvis før publisering'));
    expect(publish, contains('Lagre som utkast'));
    expect(state, contains("'source_trip_id': sourceTripId"));
    expect(publish, contains('StageTransport.ferry'));
    expect(mine, contains('Mine publiserte turer'));
    expect(mine, contains('Avpubliser'));
    expect(routes, contains("static const myPublishedRoutes = '/my-published-routes';"));
  });
}
