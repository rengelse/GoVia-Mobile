import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route map remounts when geometry changes', () {
    final widgets = File('lib/core/widgets/govia_widgets.dart').readAsStringSync();
    expect(widgets, contains('ValueKey(_routeRenderKey(points, connectPoints, showRiders))'));
  });

  test('selected route preserves every candidate and official geometry', () {
    final plan = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();
    expect(plan, contains('routeCandidates: candidates'));
    expect(plan, contains('official: candidate.id == route.id'));
    final profiles = File('lib/domain/transport_profiles.dart').readAsStringSync();
    expect(profiles, contains("label: 'Raskest'"));
    expect(profiles, contains("label: 'Balansert'"));
    expect(profiles, contains("label: 'Svingete'"));
    expect(profiles, contains("label: 'Maks svingete'"));
    expect(plan, contains('_curvatureScore'));
  });

  test('trip detail renders official route geometry', () {
    final trip = File('lib/features/trips/presentation/trip_detail_screen.dart').readAsStringSync();
    expect(trip, contains('points: _tripGeometry(stages)'));
    expect(trip, contains('candidate.id == stage.officialRouteId'));
  });
}
