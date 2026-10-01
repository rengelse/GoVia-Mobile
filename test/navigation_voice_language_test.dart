import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_voice_localizer.dart';

NavigationManeuver maneuver({
  String type = 'turn',
  String modifier = 'right',
  int? exit,
  String roadName = 'E39',
}) => NavigationManeuver(
      id: 'm1',
      sequence: 0,
      type: type,
      modifier: modifier,
      instruction: 'provider text ignored for voice',
      location: const GeoPoint(lat: 60, lon: 5),
      roadName: roadName,
      exit: exit,
    );

void main() {
  test('Norwegian voice stays Norwegian', () {
    final voice = NavigationVoiceLocalizer('nb');
    expect(voice.instruction(maneuver(), distanceMeters: 200), 'Om 200 meter, ta til høyre inn på E39');
    expect(voice.displayInstruction(maneuver()), 'Ta til høyre inn på E39');
    expect(voice.arrival(), 'Du er fremme.');
  });

  test('English voice stays English', () {
    final voice = NavigationVoiceLocalizer('en');
    expect(voice.instruction(maneuver(), distanceMeters: 200), 'In 200 meters, turn right onto E39');
    expect(voice.displayInstruction(maneuver()), 'Turn right onto E39');
    expect(voice.arrival(), 'You have arrived.');
  });

  test('roundabout exit is localized structurally', () {
    final m = maneuver(type: 'roundabout', modifier: 'right', exit: 3, roadName: '');
    expect(NavigationVoiceLocalizer('nb').instruction(m), 'Ta tredje avkjøring i rundkjøringen');
    expect(NavigationVoiceLocalizer('en').instruction(m), 'Take the 3rd exit at the roundabout');
  });
}
