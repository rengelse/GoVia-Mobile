import 'dart:math' as math;

import '../../domain/models.dart';

class NavigationSimulatorScenario {
  const NavigationSimulatorScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.stage,
    required this.defaultSpeedMps,
    this.autoStress = false,
  });

  final String id;
  final String name;
  final String description;
  final Stage stage;
  final double defaultSpeedMps;
  final bool autoStress;

  Trip get trip => Trip(
        id: 'dev-$id',
        name: 'DEV · $name',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(seconds: stage.durationSeconds)),
        start: stage.start,
        end: stage.end,
        status: TripStatus.planned,
        stages: [stage],
      );
}

List<NavigationSimulatorScenario> buildNavigationSimulatorScenarios() => [
      _scenario(
        id: 'urban',
        name: 'By + rundkjøringer',
        description: 'Normal navigasjon, flere manøvrer, fart og ankomst.',
        points: const [
          GeoPoint(lat: 60.3913, lon: 5.3221),
          GeoPoint(lat: 60.3926, lon: 5.3273),
          GeoPoint(lat: 60.3952, lon: 5.3310),
          GeoPoint(lat: 60.3987, lon: 5.3330),
          GeoPoint(lat: 60.4021, lon: 5.3302),
          GeoPoint(lat: 60.4055, lon: 5.3250),
          GeoPoint(lat: 60.4082, lon: 5.3190),
        ],
        instructions: const [
          ('depart', 'straight', 'Kjør nordover', 'Kaigaten'),
          ('turn', 'right', 'Ta til høyre', 'Strømgaten'),
          ('roundabout', 'right', 'Ta andre avkjøring i rundkjøringen', 'Åsaneveien'),
          ('turn', 'left', 'Ta til venstre', 'Myrdalsvegen'),
          ('turn', 'right', 'Hold til høyre', 'Liamyrane'),
          ('arrive', '', 'Målet er på høyre side', ''),
        ],
        profile: 'balanced',
        speedMps: 13.9,
      ),
      _scenario(
        id: 'curvy',
        name: 'Svingete fjellvei',
        description: 'Mange svinger, hyppig veiledning og variabel fart.',
        points: const [
          GeoPoint(lat: 60.4322, lon: 5.3945),
          GeoPoint(lat: 60.4350, lon: 5.4010),
          GeoPoint(lat: 60.4381, lon: 5.3980),
          GeoPoint(lat: 60.4410, lon: 5.4055),
          GeoPoint(lat: 60.4444, lon: 5.4013),
          GeoPoint(lat: 60.4470, lon: 5.4095),
          GeoPoint(lat: 60.4501, lon: 5.4040),
          GeoPoint(lat: 60.4530, lon: 5.4122),
          GeoPoint(lat: 60.4562, lon: 5.4080),
          GeoPoint(lat: 60.4590, lon: 5.4160),
          GeoPoint(lat: 60.4620, lon: 5.4115),
        ],
        instructions: const [
          ('depart', 'straight', 'Start på fjellveien', 'Gullfjellsvegen'),
          ('turn', 'right', 'Sving skarpt til høyre', 'Gullfjellsvegen'),
          ('turn', 'left', 'Sving til venstre', 'Gullfjellsvegen'),
          ('turn', 'right', 'Hold til høyre', 'Fjellvegen'),
          ('turn', 'left', 'Ta til venstre', 'Fjellvegen'),
          ('turn', 'right', 'Sving til høyre', 'Fjellvegen'),
          ('turn', 'left', 'Hold til venstre', 'Fjellvegen'),
          ('arrive', '', 'Du er fremme ved utsiktspunktet', ''),
        ],
        profile: 'max_curvy',
        speedMps: 9.7,
      ),
      _scenario(
        id: 'stress',
        name: 'Stress / feilkjøring',
        description: 'GPS-jitter, GPS-tap, kø, stopp, off-route, reroute og ankomst.',
        points: const [
          GeoPoint(lat: 60.3770, lon: 5.3320),
          GeoPoint(lat: 60.3800, lon: 5.3400),
          GeoPoint(lat: 60.3840, lon: 5.3470),
          GeoPoint(lat: 60.3890, lon: 5.3520),
          GeoPoint(lat: 60.3940, lon: 5.3490),
          GeoPoint(lat: 60.3990, lon: 5.3420),
          GeoPoint(lat: 60.4040, lon: 5.3350),
          GeoPoint(lat: 60.4090, lon: 5.3290),
        ],
        instructions: const [
          ('depart', 'straight', 'Kjør rett frem', 'Fjøsangerveien'),
          ('turn', 'left', 'Ta til venstre', 'Minde allé'),
          ('turn', 'right', 'Ta til høyre', 'Nattlandsveien'),
          ('turn', 'left', 'Hold til venstre', 'Haukelandsveien'),
          ('turn', 'right', 'Ta til høyre', 'Årstadveien'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'scenic',
        speedMps: 12.0,
        autoStress: true,
      ),
    ];

NavigationSimulatorScenario _scenario({
  required String id,
  required String name,
  required String description,
  required List<GeoPoint> points,
  required List<(String, String, String, String)> instructions,
  required String profile,
  required double speedMps,
  bool autoStress = false,
}) {
  final cumulative = <double>[0];
  for (var i = 1; i < points.length; i++) {
    cumulative.add(cumulative.last + _distance(points[i - 1], points[i]));
  }
  final total = cumulative.last.round();
  final maneuvers = <NavigationManeuver>[];
  for (var i = 0; i < instructions.length; i++) {
    final fraction = instructions.length <= 1 ? 0.0 : i / (instructions.length - 1);
    final target = total * fraction;
    final point = _pointAtDistance(points, cumulative, target.toDouble());
    final row = instructions[i];
    maneuvers.add(NavigationManeuver(
      id: '$id-m$i',
      sequence: i,
      type: row.$1,
      modifier: row.$2,
      instruction: row.$3,
      roadName: row.$4,
      location: point,
      distanceFromStartMeters: target.round(),
      distanceMeters: i + 1 < instructions.length ? (total / instructions.length).round() : 0,
      durationSeconds: i + 1 < instructions.length ? (total / speedMps / instructions.length).round() : 0,
      source: 'simulator',
      confidence: 1,
    ));
  }
  final route = RouteCandidate(
    id: 'sim-$id-route',
    name: name,
    distanceMeters: total,
    durationSeconds: (total / speedMps).round(),
    geometry: points,
    maneuvers: maneuvers,
    guidanceSource: 'simulator',
    official: true,
  );
  return NavigationSimulatorScenario(
    id: id,
    name: name,
    description: description,
    stage: Stage(
      id: 'sim-$id-stage',
      day: 0,
      order: 0,
      start: name == 'Svingete fjellvei' ? 'Arna' : 'Bergen',
      end: name == 'Svingete fjellvei' ? 'Utsiktspunkt' : 'Testmål',
      transport: StageTransport.motorcycle,
      distanceMeters: total,
      durationSeconds: route.durationSeconds,
      routeCandidates: [route],
      officialRouteId: route.id,
      routeProfile: profile,
      routePreferences: RoutePreferences(
        avoidMotorways: profile != 'fastest',
        preferScenic: profile == 'scenic' || profile == 'max_curvy',
        preferMountains: profile == 'max_curvy',
      ),
    ),
    defaultSpeedMps: speedMps,
    autoStress: autoStress,
  );
}

double _distance(GeoPoint a, GeoPoint b) {
  const radius = 6371000.0;
  final p1 = a.lat * math.pi / 180;
  final p2 = b.lat * math.pi / 180;
  final dp = (b.lat - a.lat) * math.pi / 180;
  final dl = (b.lon - a.lon) * math.pi / 180;
  final h = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * radius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

GeoPoint _pointAtDistance(List<GeoPoint> points, List<double> cumulative, double meters) {
  if (meters <= 0) return points.first;
  if (meters >= cumulative.last) return points.last;
  for (var i = 1; i < points.length; i++) {
    if (cumulative[i] < meters) continue;
    final segment = cumulative[i] - cumulative[i - 1];
    final t = segment <= 0 ? 0.0 : (meters - cumulative[i - 1]) / segment;
    return GeoPoint(
      lat: points[i - 1].lat + (points[i].lat - points[i - 1].lat) * t,
      lon: points[i - 1].lon + (points[i].lon - points[i - 1].lon) * t,
    );
  }
  return points.last;
}
