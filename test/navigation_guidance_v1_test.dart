import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/navigation/domain/navigation_guidance.dart';

void main() {
  const policy = NavigationGuidancePolicy();

  NavigationManeuver maneuver({
    String id = 'm1',
    String type = 'turn',
    String modifier = 'right',
    String instruction = 'Sving til høyre',
    String roadName = 'Bergen sentrum',
    String roadRef = 'E39',
    int? exit,
  }) => NavigationManeuver(
        id: id,
        sequence: 0,
        type: type,
        modifier: modifier,
        instruction: instruction,
        location: const GeoPoint(lat: 60.0, lon: 5.0),
        roadName: roadName,
        roadRef: roadRef,
        exit: exit,
      );

  test('prepare moves earlier as speed increases', () {
    final city = policy.thresholds(30 / 3.6);
    final motorway = policy.thresholds(110 / 3.6);
    expect(motorway.prepareMeters, greaterThan(city.prepareMeters));
    expect(city.prepareMeters, 300);
    expect(motorway.prepareMeters, greaterThan(800));
  });

  test('prepare approach now are deterministic', () {
    const speed = 80 / 3.6;
    expect(policy.phaseFor(distanceMeters: 600, speedMetersPerSecond: speed), NavigationGuidancePhase.prepare);
    expect(policy.phaseFor(distanceMeters: 200, speedMetersPerSecond: speed), NavigationGuidancePhase.approach);
    expect(policy.phaseFor(distanceMeters: 50, speedMetersPerSecond: speed), NavigationGuidancePhase.now);
  });

  test('dedupe is per maneuver and phase', () {
    final tracker = NavigationGuidanceTracker();
    final a = policy.cueFor(maneuver: maneuver(id: 'a'), distanceMeters: 200, speedMetersPerSecond: 20)!;
    final b = policy.cueFor(maneuver: maneuver(id: 'b'), distanceMeters: 200, speedMetersPerSecond: 20)!;
    expect(tracker.shouldAnnounce(a), isTrue);
    expect(tracker.shouldAnnounce(a), isFalse);
    expect(tracker.shouldAnnounce(b), isTrue);
  });

  test('roundabout uses structured exit and road metadata', () {
    final text = policy.primaryInstruction(
      maneuver(type: 'roundabout', modifier: '', instruction: 'Roundabout', roadName: 'Bergen', roadRef: 'E39', exit: 3),
    );
    expect(text, 'I rundkjøringen, ta tredje avkjøring mot E39 Bergen');
  });

  test('next maneuver produces after-next preview', () {
    expect(policy.nextInstruction(maneuver()), 'Deretter ta til høyre mot E39 Bergen sentrum');
  });

  test('roundabout without exit never degrades to slight-right guidance', () {
    final text = policy.primaryInstruction(
      maneuver(type: 'roundabout', modifier: 'slight_right', instruction: 'Sving svakt til høyre', roadName: '', roadRef: ''),
    );
    expect(text, 'Kjør inn i rundkjøringen');
  });

  test('motorway off-ramp without exit number says next exit', () {
    final text = policy.primaryInstruction(
      maneuver(type: 'off_ramp', modifier: 'right', instruction: 'Sving til høyre', roadName: 'Fjøsangerveien', roadRef: 'E39'),
    );
    expect(text, 'Ta neste avkjøring mot E39 Fjøsangerveien');
  });

  test('tracker state survives runtime recovery', () {
    final tracker = NavigationGuidanceTracker();
    final cue = policy.cueFor(maneuver: maneuver(), distanceMeters: 200, speedMetersPerSecond: 20)!;
    expect(tracker.shouldAnnounce(cue), isTrue);
    final recovered = NavigationGuidanceTracker()..restore(tracker.toJson());
    expect(recovered.shouldAnnounce(cue), isFalse);
  });
}
