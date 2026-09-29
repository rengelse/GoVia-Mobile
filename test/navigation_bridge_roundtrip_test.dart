import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('maneuver bridge JSON roundtrip preserves every canonical field', () {
    const source = NavigationManeuver(
      id: 'm-42',
      sequence: 7,
      type: 'roundabout',
      modifier: 'right',
      instruction: 'Ta tredje avkjøring',
      roadName: 'Ringveien',
      roadRef: 'E39',
      distanceMeters: 320,
      durationSeconds: 27,
      distanceFromStartMeters: 4120,
      exit: 3,
      source: 'provider',
      confidence: .94,
      location: GeoPoint(lat: 60.3913, lon: 5.3221),
    );
    final decoded = NavigationManeuver.fromJson(source.toJson());
    expect(decoded.id, source.id);
    expect(decoded.sequence, source.sequence);
    expect(decoded.type, source.type);
    expect(decoded.modifier, source.modifier);
    expect(decoded.instruction, source.instruction);
    expect(decoded.roadName, source.roadName);
    expect(decoded.roadRef, source.roadRef);
    expect(decoded.distanceMeters, source.distanceMeters);
    expect(decoded.durationSeconds, source.durationSeconds);
    expect(decoded.distanceFromStartMeters, source.distanceFromStartMeters);
    expect(decoded.exit, source.exit);
    expect(decoded.source, source.source);
    expect(decoded.confidence, source.confidence);
    expect(decoded.location.lat, source.location.lat);
    expect(decoded.location.lon, source.location.lon);
  });

  test('maneuver matrix retains structured type and modifier without instruction parsing', () {
    const cases = <(String, String)>[
      ('turn', 'right'),
      ('turn', 'left'),
      ('turn', 'slight right'),
      ('turn', 'slight left'),
      ('continue', 'straight'),
      ('turn', 'uturn'),
      ('ramp', 'right'),
      ('off ramp', 'right'),
      ('roundabout', 'right'),
    ];
    for (var i = 0; i < cases.length; i++) {
      final item = NavigationManeuver(
        id: 'm-$i',
        sequence: i,
        type: cases[i].$1,
        modifier: cases[i].$2,
        instruction: 'Tekst som ikke skal parses',
        roadName: 'Vei $i',
        roadRef: 'R$i',
        exit: i == cases.length - 1 ? 2 : null,
        location: GeoPoint(lat: 60 + i / 1000, lon: 5),
      );
      final decoded = NavigationManeuver.fromJson(item.toJson());
      expect(decoded.type, cases[i].$1);
      expect(decoded.modifier, cases[i].$2);
      expect(decoded.roadName, 'Vei $i');
      expect(decoded.roadRef, 'R$i');
    }
  });
}
