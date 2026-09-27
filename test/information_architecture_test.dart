import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile shell prioritizes discover over group', () {
    final source = File('lib/app/shell_screen.dart').readAsStringSync();
    expect(source, contains("label: 'Oppdag'"));
    expect(source, isNot(contains("label: 'Gruppe'")));
    expect(source, contains('DiscoverScreen(embedded: true)'));
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
