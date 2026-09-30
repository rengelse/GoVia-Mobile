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
      // Timing model inspired by established navigation engines: an optional
      // early cue, a normal approach cue around ~22 s, and a close cue around
      // ~5.5 s. Distance clamps keep behavior sane when nearly stationary or
      // at motorway speed.
      prepareMeters: (speed * 65.0).clamp(300.0, 1800.0).toDouble(),
      approachMeters: (speed * 22.0).clamp(90.0, 550.0).toDouble(),
      nowMeters: (speed * 5.5).clamp(25.0, 90.0).toDouble(),
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
    if (!isVoiceActionable(maneuver)) return null;
    final phase = phaseFor(distanceMeters: distanceMeters, speedMetersPerSecond: speedMetersPerSecond);
    if (phase == null) return null;
    if (phase == NavigationGuidancePhase.prepare && !_usesPrepareCue(maneuver, speedMetersPerSecond)) return null;
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


  bool _usesPrepareCue(NavigationManeuver maneuver, double speedMetersPerSecond) {
    final type = semanticType(maneuver);
    final complex = type == 'roundabout' || type == 'exit' || type == 'on ramp' || type == 'fork' || type == 'merge';
    // Ordinary urban turns stay deliberately quiet: approach + now is enough.
    // Early prepare is reserved for genuinely complex/high-speed decisions.
    return speedMetersPerSecond >= 25.0 || (complex && speedMetersPerSecond >= 16.7);
  }

  String primaryInstruction(NavigationManeuver maneuver, {bool concise = false}) {
    final type = semanticType(maneuver);
    final modifier = normalizeToken(maneuver.modifier);
    final destination = roadLabel(maneuver);

    if (type == 'roundabout') {
      final exit = maneuver.exit;
      if (exit != null && exit > 0) {
        final base = concise ? 'Ta ${ordinal(exit)} avkjøring' : 'I rundkjøringen, ta ${ordinal(exit)} avkjøring';
        return destination.isEmpty ? base : '$base mot $destination';
      }
      final base = concise ? 'Kjør inn i rundkjøringen' : 'Kjør inn i rundkjøringen';
      return destination.isEmpty ? base : '$base mot $destination';
    }

    if (type == 'exit') {
      final exit = maneuver.exit;
      final base = exit != null && exit > 0 ? 'Ta avkjøring $exit' : 'Ta neste avkjøring';
      return destination.isEmpty ? base : '$base mot $destination';
    }

    if (type == 'on ramp') {
      final base = 'Ta påkjøringsrampen';
      return destination.isEmpty ? base : '$base mot $destination';
    }

    if (type == 'merge') {
      final side = modifier.contains('left') ? ' til venstre' : modifier.contains('right') ? ' til høyre' : '';
      final base = 'Flett inn$side';
      return destination.isEmpty ? base : '$base mot $destination';
    }

    if (type == 'fork') {
      final side = modifier.contains('left') ? 'venstre' : modifier.contains('right') ? 'høyre' : '';
      final base = side.isEmpty ? 'Hold kursen' : 'Hold til $side';
      return destination.isEmpty ? base : '$base mot $destination';
    }

    if (type == 'continue' || type == 'new name' || type == 'notification') {
      return destination.isEmpty ? 'Fortsett' : 'Fortsett på $destination';
    }

    final direction = switch (modifier) {
      'left' || 'slight left' || 'sharp left' => 'Ta til venstre',
      'right' || 'slight right' || 'sharp right' => 'Ta til høyre',
      'uturn' || 'u turn' => 'Snu',
      _ => '',
    };
    if (direction.isNotEmpty) {
      return destination.isEmpty ? direction : '$direction mot $destination';
    }

    final fallback = clean(maneuver.instruction);
    if (fallback.isNotEmpty) return fallback;
    return destination.isEmpty ? 'Fortsett' : 'Fortsett mot $destination';
  }

  String semanticType(NavigationManeuver maneuver) {
    final type = normalizeToken(maneuver.type);
    if (type.contains('roundabout') || type == 'rotary' || type.contains('traffic circle')) return 'roundabout';
    if (type.contains('off ramp') || type == 'exit' || type.contains('motorway exit')) return 'exit';
    if (type.contains('on ramp') || type == 'onramp') return 'on ramp';
    if (type == 'new name' || type == 'newname') return 'new name';
    if (type == 'end of road' || type == 'endofroad') return 'end of road';
    return type;
  }

  bool isVoiceActionable(NavigationManeuver maneuver) {
    final type = semanticType(maneuver);
    final source = normalizeToken(maneuver.source);
    final modifier = normalizeToken(maneuver.modifier);

    if (source == 'geometry emergency') return false;
    if ({'notification', 'new name', 'depart', 'arrive'}.contains(type)) return false;

    // Do not narrate road curvature. A slight direction change is not a driving
    // decision unless the provider gives it a stronger semantic type such as
    // roundabout/exit/fork/merge.
    if (type == 'turn' && {'slight left', 'slight right'}.contains(modifier)) return false;

    // Some providers encode a real junction as `continue` plus a decisive
    // left/right modifier. Keep those audible, but keep straight/slight
    // continuation silent.
    if (type == 'continue') {
      return {'left', 'right', 'sharp left', 'sharp right', 'uturn', 'u turn'}.contains(modifier);
    }

    return type.isNotEmpty;
  }

  String normalizeToken(String value) => clean(value).toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');

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
