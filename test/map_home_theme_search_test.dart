import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map home follows app theme and uses light/dark map styles', () {
    final home = File('lib/features/home/presentation/home_screen.dart').readAsStringSync();
    final app = File('lib/app/govia_app.dart').readAsStringSync();
    final state = File('lib/app/app_state.dart').readAsStringSync();

    expect(home, contains("https://tiles.openfreemap.org/styles/dark"));
    expect(home, contains("https://tiles.openfreemap.org/styles/liberty"));
    expect(home, contains("Theme.of(context).brightness == Brightness.dark"));
    expect(app, contains('darkTheme: buildGoViaTheme()'));
    expect(app, contains('themeMode: switch (state.appThemeMode)'));
    expect(state, contains("store.writeString('app_theme_mode', mode)"));
  });

  test('map home search is a real destination search and seeds trip planning', () {
    final home = File('lib/features/home/presentation/home_screen.dart').readAsStringSync();
    final service = File('lib/core/location/place_search_service.dart').readAsStringSync();
    final planner = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();

    expect(home, contains('Søk etter destinasjon, sted eller adresse'));
    expect(home, contains('_DestinationSearchSheet'));
    expect(home, contains('PlaceSearchService'));
    expect(home, contains('PlanTripArgs(destinationLabel: result.label, destination: result.point)'));
    expect(service, contains('photon.komoot.io'));
    expect(service, contains('Accept-Language'));
    expect(planner, contains('class PlanTripArgs'));
    expect(planner, contains('selectedEnd = _PlaceSuggestion'));
  });

  test('empty discovery feed does not render the old oversized placeholder card', () {
    final home = File('lib/features/home/presentation/home_screen.dart').readAsStringSync();
    expect(home, isNot(contains("Text('Oppdag turer'")));
    expect(home, isNot(contains('Publiserte GoVia-turer vises her når de er tilgjengelige.')));
  });
}
