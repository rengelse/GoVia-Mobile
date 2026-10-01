import '../../../domain/models.dart';

class NavigationVoiceLocalizer {
  const NavigationVoiceLocalizer(this.language);

  final String language;
  bool get english => language == 'en';
  String get locale => english ? 'en-US' : 'nb-NO';

  String arrival() => english ? 'You have arrived.' : 'Du er fremme.';

  String displayInstruction(NavigationManeuver maneuver) => _maneuver(maneuver);

  String instruction(NavigationManeuver maneuver, {double? distanceMeters}) {
    final core = displayInstruction(maneuver);
    if (distanceMeters == null || distanceMeters <= 60 || maneuver.type == 'arrive') return core;
    final distance = _distance(distanceMeters);
    return english ? 'In $distance, ${_lowerLead(core)}' : 'Om $distance, ${_lowerLead(core)}';
  }

  String _maneuver(NavigationManeuver m) {
    final type = m.type.toLowerCase();
    final modifier = m.modifier.toLowerCase();
    final road = m.roadName.trim();
    final roadSuffix = road.isEmpty ? '' : (english ? ' onto $road' : ' inn på $road');
    if (type == 'arrive') return arrival();
    if (type == 'roundabout' || type == 'rotary') {
      final exit = m.exit;
      if (exit != null && exit > 0) {
        return english
            ? 'Take the ${_ordinalEn(exit)} exit at the roundabout'
            : 'Ta ${_ordinalNb(exit)} avkjøring i rundkjøringen';
      }
      return english ? 'Enter the roundabout' : 'Kjør inn i rundkjøringen';
    }
    if (type == 'off_ramp') return english ? 'Take the exit$roadSuffix' : 'Ta avkjøringen$roadSuffix';
    if (type == 'on_ramp') return english ? 'Take the ramp$roadSuffix' : 'Ta påkjøringen$roadSuffix';
    if (type == 'fork') {
      if (modifier.contains('left')) return english ? 'Keep left$roadSuffix' : 'Hold til venstre$roadSuffix';
      if (modifier.contains('right')) return english ? 'Keep right$roadSuffix' : 'Hold til høyre$roadSuffix';
    }
    if (type == 'merge') return english ? 'Merge$roadSuffix' : 'Flett inn$roadSuffix';
    if (modifier.contains('left')) return english ? 'Turn left$roadSuffix' : 'Ta til venstre$roadSuffix';
    if (modifier.contains('right')) return english ? 'Turn right$roadSuffix' : 'Ta til høyre$roadSuffix';
    return english ? 'Continue$roadSuffix' : 'Fortsett$roadSuffix';
  }

  String _distance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      final value = km >= 10 ? km.round().toString() : km.toStringAsFixed(1).replaceAll('.', english ? '.' : ',');
      return english ? '$value kilometers' : '$value kilometer';
    }
    final rounded = meters >= 100 ? (meters / 50).round() * 50 : (meters / 10).round().clamp(1, 99) * 10;
    return english ? '$rounded meters' : '$rounded meter';
  }

  String _ordinalNb(int n) => switch (n) {1 => 'første', 2 => 'andre', 3 => 'tredje', 4 => 'fjerde', 5 => 'femte', _ => '$n.'};
  String _ordinalEn(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    return switch (n % 10) {1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th'};
  }

  String _lowerLead(String value) => value.isEmpty ? value : value[0].toLowerCase() + value.substring(1);
}
