import 'dart:math' as math;

import '../../domain/models.dart';

class NavigationSimulatorRoutePoint {
  const NavigationSimulatorRoutePoint(this.name, this.point);

  final String name;
  final GeoPoint point;

  List<double> get coord => [point.lon, point.lat];
}

class NavigationSimulatorScenario {
  const NavigationSimulatorScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.stage,
    required this.defaultSpeedMps,
    required this.routePoints,
    this.autoStress = false,
    this.roadNetworkResolved = false,
  });

  final String id;
  final String name;
  final String description;
  final Stage stage;
  final double defaultSpeedMps;
  final List<NavigationSimulatorRoutePoint> routePoints;
  final bool autoStress;
  final bool roadNetworkResolved;

  NavigationSimulatorScenario withRoadNetworkStage(Stage resolvedStage) => NavigationSimulatorScenario(
        id: id,
        name: name,
        description: description,
        stage: resolvedStage,
        defaultSpeedMps: defaultSpeedMps,
        routePoints: routePoints,
        autoStress: autoStress,
        roadNetworkResolved: true,
      );

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
        id: 'country-road',
        name: 'Landevei – svak kurve',
        description: 'Kontrollerer stabil progress og at svak kurve/continue ikke gir unødvendig stemmeveiledning.',
        points: const [
          GeoPoint(lat: 60.3318, lon: 5.3118),
          GeoPoint(lat: 60.3257, lon: 5.3168),
          GeoPoint(lat: 60.3192, lon: 5.3209),
        ],
        instructions: const [
          ('depart', 'straight', 'Start', 'Osvegen'),
          ('continue', 'slight_right', 'Følg veien', 'Osvegen'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'balanced',
        speedMps: 18.0,
      ),
      _scenario(
        id: 'motorway-exit',
        name: 'E39 – motorvei og avkjøring',
        description: 'Kontrollerer motorveiflyt, off-ramp, etterfølgende manøver og høyere fart.',
        points: const [
          GeoPoint(lat: 60.3638, lon: 5.3512),
          GeoPoint(lat: 60.3492, lon: 5.3508),
          GeoPoint(lat: 60.3340, lon: 5.3468),
          GeoPoint(lat: 60.3207, lon: 5.3408),
        ],
        instructions: const [
          ('depart', 'straight', 'Kjør inn på E39', 'E39'),
          ('off_ramp', 'right', 'Ta avkjøringen', 'Fjøsangerveien'),
          ('turn', 'right', 'Ta til høyre', 'Fjøsangerveien'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'fastest',
        speedMps: 23.0,
      ),
      _scenario(
        id: 'roundabout',
        name: 'Rundkjøring – avkjøringsnummer',
        description: 'Kontrollerer roundabout-semantikk, exit-nummer og én konsistent stemmeinstruksjon.',
        points: const [
          GeoPoint(lat: 60.2939, lon: 5.3303),
          GeoPoint(lat: 60.2912, lon: 5.3278),
          GeoPoint(lat: 60.2887, lon: 5.3319),
          GeoPoint(lat: 60.2867, lon: 5.3370),
        ],
        instructions: const [
          ('depart', 'straight', 'Start', 'Laguneveien'),
          ('roundabout', 'right', 'Ta tredje avkjøring i rundkjøringen', 'Fanavegen'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'balanced',
        speedMps: 11.0,
      ),
      _scenario(
        id: 'intersection',
        name: 'Kryss – tydelig høyresving',
        description: 'Kontrollerer vanlig turn-manøver uten å blande inn rundkjøring eller motorvei.',
        points: const [
          GeoPoint(lat: 60.3897, lon: 5.3330),
          GeoPoint(lat: 60.3881, lon: 5.3373),
          GeoPoint(lat: 60.3858, lon: 5.3397),
        ],
        instructions: const [
          ('depart', 'straight', 'Start', 'Nygårdsgaten'),
          ('turn', 'right', 'Ta til høyre', 'Møllendalsveien'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'balanced',
        speedMps: 9.0,
      ),
      _scenario(
        id: 'speed-limits',
        name: 'Fartsgrenser – 80 → 60 → 40',
        description: 'Kontrollerer at provider-/simulatorseksjoner følger ruteprogress og vises korrekt.',
        points: const [
          GeoPoint(lat: 60.3095, lon: 5.3395),
          GeoPoint(lat: 60.3020, lon: 5.3325),
          GeoPoint(lat: 60.2950, lon: 5.3250),
          GeoPoint(lat: 60.2890, lon: 5.3180),
        ],
        instructions: const [
          ('depart', 'straight', 'Start', 'E39'),
          ('continue', 'straight', 'Fortsett', 'E39'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'fastest',
        speedMps: 18.0,
      ),
      _scenario(
        id: 'reroute',
        name: 'Reroute – feilkjøring',
        description: 'Kjører automatisk GPS-avvik for å kontrollere deviation, reroute og retur til aktiv navigasjon.',
        points: const [
          GeoPoint(lat: 60.3770, lon: 5.3320),
          GeoPoint(lat: 60.3810, lon: 5.3400),
          GeoPoint(lat: 60.3860, lon: 5.3470),
          GeoPoint(lat: 60.3920, lon: 5.3490),
        ],
        instructions: const [
          ('depart', 'straight', 'Start', 'Fjøsangerveien'),
          ('turn', 'left', 'Ta til venstre', 'Minde allé'),
          ('turn', 'right', 'Ta til høyre', 'Nattlandsveien'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'balanced',
        speedMps: 12.0,
        autoStress: true,
      ),
      _scenario(
        id: 'arrival',
        name: 'Ankomst – fullføringsflyt',
        description: 'Kort rute for ARRIVED → fullføringsdialog → COMPLETED/avsluttet navigasjon.',
        points: const [
          GeoPoint(lat: 60.3925, lon: 5.3233),
          GeoPoint(lat: 60.3940, lon: 5.3270),
          GeoPoint(lat: 60.3957, lon: 5.3298),
        ],
        instructions: const [
          ('depart', 'straight', 'Start', 'Lars Hilles gate'),
          ('arrive', '', 'Du er fremme', ''),
        ],
        profile: 'balanced',
        speedMps: 8.0,
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
    routePoints: [
      for (var i = 0; i < points.length; i++)
        NavigationSimulatorRoutePoint(
          i == 0 ? (name == 'Svingete fjellvei' ? 'Arna' : 'Bergen') : i == points.length - 1 ? (name == 'Svingete fjellvei' ? 'Utsiktspunkt' : 'Testmål') : 'Via $i',
          points[i],
        ),
    ],
    autoStress: autoStress,
  );
}


double _routeLength(List<GeoPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _distance(points[i - 1], points[i]);
  }
  return total;
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


RouteCandidate parseNavigationSimulatorRoadRoute(
  Map<String, dynamic> response, {
  required NavigationSimulatorScenario scenario,
}) {
  final data = response['data'];
  if (data is! Map) {
    throw StateError('Ugyldig rutesvar fra GoVia API.');
  }
  final raw = Map<String, dynamic>.from(data);
  final geometry = (raw['geometry'] as List? ?? const [])
      .whereType<List>()
      .where((point) => point.length >= 2)
      .map((point) => GeoPoint(
            lat: (point[1] as num).toDouble(),
            lon: (point[0] as num).toDouble(),
          ))
      .toList(growable: false);
  if (geometry.length < 2) {
    throw StateError('Rutesvaret mangler veinett-geometri.');
  }
  final maneuvers = (raw['maneuvers'] as List? ?? const [])
      .whereType<Map>()
      .map((value) => NavigationManeuver.fromJson(Map<String, dynamic>.from(value)))
      .toList(growable: false);
  final distanceMeters = (raw['distance'] as num? ?? _routeLength(geometry)).round();
  final providerSpeedLimits = RouteSpeedLimitSection.fromRouteJson(raw, geometry);
  return RouteCandidate(
    id: 'sim-road-${scenario.id}-${DateTime.now().microsecondsSinceEpoch}',
    name: scenario.name,
    distanceMeters: distanceMeters,
    durationSeconds: (raw['duration'] as num? ?? (_routeLength(geometry) / scenario.defaultSpeedMps)).round(),
    geometry: geometry,
    maneuvers: maneuvers,
    speedLimitSections: providerSpeedLimits.isNotEmpty
        ? providerSpeedLimits
        : _simulatorSpeedLimitSections(distanceMeters, geometry.length),
    guidanceSource: raw['guidanceSource']?.toString() ?? 'route-provider',
    official: true,
  );
}



List<RouteSpeedLimitSection> _simulatorSpeedLimitSections(int distanceMeters, int geometryPointCount) {
  if (distanceMeters <= 0) return const [];
  final cuts = <double>[0.0, 0.18, 0.42, 0.72, 0.90, 1.0];
  final speeds = <int>[30, 50, 80, 60, 50];
  return List.generate(speeds.length, (index) {
    final start = (distanceMeters * cuts[index]).round();
    final end = (distanceMeters * cuts[index + 1]).round().clamp(start + 1, distanceMeters).toInt();
    final lastPathIndex = (geometryPointCount - 1).clamp(1, 1 << 30).toInt();
    final startPathIndex = (lastPathIndex * cuts[index]).floor().clamp(0, lastPathIndex - 1).toInt();
    final endPathIndex = (lastPathIndex * cuts[index + 1]).ceil().clamp(startPathIndex + 1, lastPathIndex).toInt();
    return RouteSpeedLimitSection(
      startDistanceMeters: start,
      endDistanceMeters: end,
      speedLimitKph: speeds[index],
      startPathIndex: startPathIndex,
      endPathIndex: endPathIndex,
      source: 'simulator',
      confidence: 1.0,
    );
  }).where((section) => section.endDistanceMeters > section.startDistanceMeters).toList(growable: false);
}

int navigationSemanticScore(List<NavigationManeuver> maneuvers) {
  var score = 0;
  for (final maneuver in maneuvers) {
    final type = maneuver.type.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
    if (type.contains('roundabout') || type == 'rotary') {
      score += 8;
    } else if (type.contains('off ramp') || type == 'exit' || type.contains('motorway exit')) {
      score += 7;
    } else if (type.contains('on ramp') || type == 'fork' || type == 'merge') {
      score += 5;
    } else if (type == 'turn' || type == 'end of road') {
      score += 2;
    } else if (type == 'continue') {
      score += 1;
    }
    if (maneuver.exit != null && maneuver.exit! > 0) score += 2;
  }
  return score;
}

List<String> navigationSemanticTypes(List<NavigationManeuver> maneuvers) =>
    maneuvers.map((m) => m.type.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ')).toList(growable: false);

bool hasRoundaboutSemantic(List<NavigationManeuver> maneuvers) =>
    navigationSemanticTypes(maneuvers).any((type) => type.contains('roundabout') || type == 'rotary');

Stage buildNavigationSimulatorRoadStage(
  NavigationSimulatorScenario scenario,
  RouteCandidate route,
) {
  final old = scenario.stage;
  return old.copyWith(
    distanceMeters: route.distanceMeters,
    durationSeconds: route.durationSeconds,
    routeCandidates: [route],
    officialRouteId: route.id,
  );
}
