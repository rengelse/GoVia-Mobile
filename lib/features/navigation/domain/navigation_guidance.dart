import '../../../domain/models.dart';

enum NavigationGuidancePhase { prepare, approach, now }

class NavigationGuidanceThresholds {
  const NavigationGuidanceThresholds({required this.prepareMeters, required this.approachMeters, required this.nowMeters});

  final double prepareMeters;
  final double approachMeters;
  final double nowMeters;
}

class NavigationGuidanceCue {
  const NavigationGuidanceCue({
    required this.maneuverId,
    required this.phase,
    required this.primaryText,
    required this.spokenText,
    required this.distanceMeters,
  });

  final String maneuverId;
  final NavigationGuidancePhase phase;
  final String primaryText;
  final String spokenText;
  final double distanceMeters;

  String get dedupeKey => '$maneuverId:${phase.name}';
}

/// Deterministic Guidance v1 policy shared by phone behavior tests and mirrored by Android Auto.
/// NavigationSession remains the authority for maneuver progression and route state.
class NavigationGuidancePolicy {
  const NavigationGuidancePolicy();

  NavigationGuidanceThresholds thresholds(double speedMetersPerSecond) {
    final speed = speedMetersPerSecond.clamp(0.0, 45.0).toDouble();
    return NavigationGuidanceThresholds(
      prepareMeters: (speed * 28.0).clamp(300.0, 1100.0).toDouble(),
      approachMeters: (speed * 10.0).clamp(120.0, 380.0).toDouble(),
      nowMeters: (speed * 2.5).clamp(45.0, 80.0).toDouble(),
    );
  }

  NavigationGuidancePhase? phaseFor({required double distanceMeters, required double speedMetersPerSecond}) {
    final t = thresholds(speedMetersPerSecond);
    if (distanceMeters <= t.nowMeters) return NavigationGuidancePhase.now;
    if (distanceMeters <= t.approachMeters) return NavigationGuidancePhase.approach;
    if (distanceMeters <= t.prepareMeters) return NavigationGuidancePhase.prepare;
    return null;
  }

  NavigationGuidanceCue? cueFor({
    required NavigationManeuver maneuver,
    required double distanceMeters,
    required double speedMetersPerSecond,
  }) {
    final phase = phaseFor(distanceMeters: distanceMeters, speedMetersPerSecond: speedMetersPerSecond);
    if (phase == null) return null;
    final primary = primaryInstruction(maneuver, concise: phase == NavigationGuidancePhase.now);
    final spoken = phase == NavigationGuidancePhase.now ? primary : 'Om ${spokenDistance(distanceMeters)}, $primary';
    return NavigationGuidanceCue(
      maneuverId: maneuver.id,
      phase: phase,
      primaryText: primary,
      spokenText: spoken,
      distanceMeters: distanceMeters,
    );
  }

  String primaryInstruction(NavigationManeuver maneuver, {bool concise = false}) {
    final type = maneuver.type.trim().toLowerCase();
    final modifier = maneuver.modifier.trim().toLowerCase();
    final destination = roadLabel(maneuver);

    if (type.contains('roundabout') || type == 'rotary') {
      final exit = maneuver.exit;
      if (exit != null && exit > 0) {
        final base = concise ? 'Ta ${ordinal(exit)} avkjøring' : 'I rundkjøringen, ta ${ordinal(exit)} avkjøring';
        return destination.isEmpty ? base : '$base mot $destination';
      }
    }

    if (maneuver.exit != null && maneuver.exit! > 0 && (type.contains('exit') || type.contains('off ramp') || type.contains('off_ramp'))) {
      final base = 'Ta avkjøring ${maneuver.exit}';
      return destination.isEmpty ? base : '$base mot $destination';
    }

    final direction = switch (modifier) {
      'left' || 'slight left' || 'sharp left' => 'Ta til venstre',
      'right' || 'slight right' || 'sharp right' => 'Ta til høyre',
      'uturn' || 'u-turn' => 'Snu',
      _ => '',
    };
    if (direction.isNotEmpty) {
      return destination.isEmpty ? direction : '$direction mot $destination';
    }

    final fallback = clean(maneuver.instruction);
    if (fallback.isNotEmpty) return fallback;
    return destination.isEmpty ? 'Fortsett' : 'Fortsett mot $destination';
  }

  String nextInstruction(NavigationManeuver maneuver) {
    final primary = primaryInstruction(maneuver, concise: true);
    if (primary.isEmpty) return 'Deretter fortsett';
    final sentence = primary.length == 1 ? primary.toLowerCase() : '${primary[0].toLowerCase()}${primary.substring(1)}';
    return 'Deretter $sentence';
  }

  String roadLabel(NavigationManeuver maneuver) {
    final ref = clean(maneuver.roadRef);
    final name = clean(maneuver.roadName);
    if (ref.isEmpty) return name;
    if (name.isEmpty || name.toLowerCase().contains(ref.toLowerCase())) return ref;
    return '$ref $name';
  }

  String spokenDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(km >= 5 ? 0 : 1)} kilometer';
    }
    final rounded = meters >= 300 ? (meters / 100).round() * 100 : meters >= 100 ? (meters / 50).round() * 50 : (meters / 10).round() * 10;
    return '$rounded meter';
  }

  String ordinal(int value) => switch (value) {
        1 => 'første',
        2 => 'andre',
        3 => 'tredje',
        4 => 'fjerde',
        5 => 'femte',
        6 => 'sjette',
        7 => 'sjuende',
        8 => 'åttende',
        9 => 'niende',
        10 => 'tiende',
        _ => '$value.',
      };

  String clean(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class NavigationGuidanceTracker {
  NavigationGuidanceTracker([Iterable<String> restored = const []]) : _announced = restored.toSet();

  final Set<String> _announced;

  bool shouldAnnounce(NavigationGuidanceCue cue) => _announced.add(cue.dedupeKey);

  void reset() => _announced.clear();

  Map<String, dynamic> toJson() => {'announced': _announced.toList(growable: false)..sort()};

  void restore(Object? json) {
    _announced.clear();
    if (json is! Map) return;
    final values = json['announced'];
    if (values is List) _announced.addAll(values.map((item) => item.toString()));
  }
}
