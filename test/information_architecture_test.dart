import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile shell uses the locked map-first three-tab navigation', () {
    final source = File('lib/app/shell_screen.dart').readAsStringSync();
    expect(source, contains("label: 'Kart'"));
    expect(source, contains("label: 'Varsler'"));
    expect(source, contains("label: 'Profil'"));
    expect(source, isNot(contains("label: 'Turer'")));
    expect(source, isNot(contains("label: 'Hjem'")));
    expect(source, isNot(contains("label: 'Oppdag'")));
    expect(source, isNot(contains("label: 'Ny tur'")));
    expect(source, isNot(contains('TripsScreen()')));
    expect(source, contains('NotificationsScreen(embedded: true)'));
    expect(source, contains('ProfileScreen(embedded: true)'));
  });

  test('trip hub owns existing and new trip entry points without decorative map', () {
    final source = File('lib/features/new_trip/presentation/new_trip_screen.dart').readAsStringSync();
    expect(source, contains("AppBar(title: const Text('Turer'))"));
    expect(source, contains("'Mine turer'"));
    expect(source, contains('AppRoutes.trips'));
    expect(source, contains("'Hent fra GoVia Desktop'"));
    expect(source, contains("'Planlegg tur'"));
    expect(source, contains("'Opprett rundtur'"));
    expect(source, contains("'Ta opp tur'"));
    expect(source, isNot(contains('RouteMapCard')));
  });

  test('map home uses published routes for the discovery carousel', () {
    final source = File('lib/features/home/presentation/home_screen.dart').readAsStringSync();
    expect(source, contains('state.publishedRoutes'));
    expect(source, contains('TripDiscoveryCarousel'));
    expect(source, contains("label: const Text('Turer'"));
    expect(File('lib/features/home/domain/map_home_preferences.dart').readAsStringSync(), contains('https://tiles.openfreemap.org/styles/dark'));
    expect(source, isNot(contains('GoVia Premium')));
    expect(source, isNot(contains('Oppdag nye eventyr')));
  });

  test('profile contains settings and no trip status dashboard', () {
    final source = File('lib/features/profile/presentation/profile_screen.dart').readAsStringSync();
    expect(source, contains("SectionTitle('Konto')"));
    expect(source, contains("SectionTitle('Navigasjon og transport')"));
    expect(source, contains("SectionTitle('Personvern og deling')"));
    expect(source, isNot(contains("_StatCard(label: 'Planlagt'")));
    expect(source, isNot(contains("_StatCard(label: 'Aktiv'")));
    expect(source, isNot(contains("_StatCard(label: 'Fullført'")));
  });

  test('trips owns trip status navigation', () {
    final source = File('lib/features/trips/presentation/trips_screen.dart').readAsStringSync();
    expect(source, contains("title: const Text('Mine turer')"));
    expect(source, contains("_chip(TripStatus.planned, 'Planlagt')"));
    expect(source, contains("_chip(TripStatus.active, 'Aktiv')"));
    expect(source, contains("_chip(TripStatus.completed, 'Fullført')"));
    expect(source, contains("_chip(TripStatus.archived, 'Arkiv')"));
  });

  test('discover focuses on community routes without mine trips dashboard', () {
    final source = File('lib/features/discover/presentation/discover_screen.dart').readAsStringSync();
    expect(source, contains("'Nær meg'"));
    expect(source, contains("'Globalt'"));
    expect(source, isNot(contains("Text('Mine turer'")));
  });
}
