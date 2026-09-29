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
    String source = 'provider',
    double confidence = 1,
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
        source: source,
        confidence: confidence,
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

  test('geometry-only turn is silent instead of inventing a road decision', () {
    final cue = policy.cueFor(
      maneuver: maneuver(type: 'turn', modifier: 'right', source: 'geometry-emergency', confidence: .25),
      distanceMeters: 120,
      speedMetersPerSecond: 15,
    );
    expect(cue, isNull);
  });

  test('OSRM informational new-name and notification steps are silent', () {
    expect(
      policy.cueFor(maneuver: maneuver(type: 'new_name', modifier: 'slight_right'), distanceMeters: 120, speedMetersPerSecond: 15),
      isNull,
    );
    expect(
      policy.cueFor(maneuver: maneuver(type: 'notification', modifier: 'left'), distanceMeters: 120, speedMetersPerSecond: 15),
      isNull,
    );
  });

  test('continue never turns road curvature into left-right voice', () {
    final text = policy.primaryInstruction(maneuver(type: 'continue', modifier: 'slight_right', roadName: 'E39', roadRef: ''));
    expect(text, 'Fortsett på E39');
  });

  test('structured fork and on-ramp keep decision semantics', () {
    expect(policy.primaryInstruction(maneuver(type: 'fork', modifier: 'left', roadName: '', roadRef: '')), 'Hold til venstre');
    expect(policy.primaryInstruction(maneuver(type: 'on_ramp', modifier: 'right', roadName: 'E39', roadRef: '')), 'Ta påkjøringsrampen mot E39');
  });

  test('tracker state survives runtime recovery', () {
    final tracker = NavigationGuidanceTracker();
    final cue = policy.cueFor(maneuver: maneuver(), distanceMeters: 200, speedMetersPerSecond: 20)!;
    expect(tracker.shouldAnnounce(cue), isTrue);
    final recovered = NavigationGuidanceTracker()..restore(tracker.toJson());
    expect(recovered.shouldAnnounce(cue), isFalse);
  });
}
