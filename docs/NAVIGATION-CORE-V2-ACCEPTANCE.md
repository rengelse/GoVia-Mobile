# Navigation Core v2 Acceptance Gate

This document is the release gate for Navigation Core v2. A release is not approved until every executable row is green in CI and all blocked rows have been resolved or explicitly removed from scope before release.

| ID | Area | Acceptance implementation | Current candidate |
|---|---|---|---|
| A | Normal navigation | Shared golden traces + NavigationSession behavior tests | PASS in RC6 GitHub CI |
| B | Exactly one active Stage | Stage identity guards in both cores + stage selection tests | PASS candidate |
| C | Multi-stage | Stage model/selection lifecycle tests + explicit active-stage persistence | PASS candidate |
| D | Maneuver/guidance | Structured maneuver matrix + bridge roundtrip; no instruction parsing | PASS candidate |
| E | Geometry | Loop, repeated-coordinate crossing, out/back, serpentine, parallel/intersection tests | PASS candidate |
| F | GPS quality | Good/degraded/poor/unknown handling + poor-first + teleport guard | PASS candidate |
| G | Timestamp handling | Last-seen watermark + stale/duplicate/out-of-order tests | PASS candidate |
| H | Arrival | Three credible fixes + terminal ARRIVED + recovery | PASS candidate |
| I | Off-route | Repeated-fix hysteresis + standalone native smoke | PASS candidate |
| J | Reroute | Stage identity immutable; plannedRoute and activeRoute separated | PASS candidate |
| K | Stale reroute race | Phone and AA validate trip/stage/route/session revision | PASS candidate |
| L | POI/waypoints after reroute | Phone and AA reproject waypoint distance onto replacement geometry | PASS candidate |
| M | AA screen reattach | Same-session reattach behavior retained | PASS candidate |
| N | Process recovery | Dart NavigationSession snapshot + AA snapshot; route/stage identity validation | PASS candidate |
| O | Persistence performance | Route definition separated from throttled 5 s runtime snapshot | PASS candidate |
| P | Foreground service lifecycle | Pure lifecycle decision + service implementation; idle service does not enter foreground | PASS candidate |
| Q | AutoDrive simulator | Shared Navigation Core contract; explicit realistic accuracy; development gate | PASS candidate |
| R | Phone/AA parity | Shared CSV golden traces consumed by Dart and Kotlin | PASS in RC6 GitHub CI |
| S | Bridge serialization | Canonical NavigationManeuver.toJson/fromJson roundtrip preserves all fields | PASS candidate |
| T | Source hygiene | Legacy engine/classes/tests absent; verifier checks current architecture | PASS in RC6 GitHub CI |
| U | Real tests vs source strings | Runtime behavior moved into Dart/Kotlin tests and standalone native smoke | PASS candidate |
| V | Build/CI gate | One acceptance script runs verifier + analyze + Flutter tests + Gradle native tests | PASS in RC6 GitHub CI |
| W | Artifact gate | FULL/UPDATE + apply/diff/SHA verification | PASS for final v0.1.86 candidate; final versioned CI remains before tag |

## Root-cause groups found against v0.1.85

1. **GPS acceptance boundary was incomplete.** A projection rejected as an implausible jump could still update arrival/off-route state.
2. **Timestamp ordering tracked accepted movement, not observed GPS order.** A newer poor fix followed by an older good fix could let the older fix move navigation.
3. **Phone/AA continuity semantics had drifted.** Dart used `_state == null`, while Kotlin used accepted continuity. After a poor first fix, the two cores could behave differently.
4. **Reroute identity protection was asymmetric.** Android Auto validated trip/stage/route/revision; phone had no equivalent async-result guard.
5. **Reroute waypoint reprojection was asymmetric.** Android Auto recalculated route positions; phone kept old `distanceFromStartMeters`.
6. **Acceptance coverage was fragmented.** Important behaviors existed as isolated tests, but there was no shared Phone/AA trace source and several lifecycle areas remain untested.

## Release blockers still open

There are no known Navigation Core v2 code blockers in the acceptance matrix. RC6 passed the complete GitHub acceptance gate, including verifier, Kotlin smoke, `flutter analyze`, all Flutter tests, native Android unit tests and APK build.

The only remaining release step is to run the same gate once on the final versioned `v0.1.86+87` commit. If that run is green, tag `v0.1.86`.
