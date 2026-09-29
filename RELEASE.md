# GoVia Mobile v0.1.101+102 Speed Limit Runtime Diagnostics
## Navigation Map Controls & Road Speed Limit

- Android Auto navigation now has one map-view action that cycles Perspective → North up → Overview.
- Perspective reuses the existing 60° heading-follow camera; North up follows position at bearing 0°; Overview frames the active route and does not get overwritten by the next GPS fix.
- Recenter exits Overview back to the last follow mode.
- The map action strip stays within Android Auto limits by keeping Pan + Recenter + one camera-mode action; dedicated +/- buttons are removed while native map scaling gestures remain supported.
- Route speed-limit sections are carried as route metadata from provider response through RouteCandidate, local snapshots, Android Auto bridge, CarStage persistence and rerouting.
- Android Auto resolves the current legal speed limit from Navigation Core route progress and renders a Norwegian/European speed-limit sign inside the host safe area.
- Unknown, invalid or low-confidence limits are hidden rather than guessed. Current vehicle speed is not displayed.
- TomTom-style offset/length sections, point-index sections and nested speed-limit section collections are accepted.
- DEV simulator gets deterministic 30/50/80/60/50 transitions only when the routing provider does not return real speed-limit metadata.
- New regression tests cover route speed-limit parsing, camera modes and the native-cockpit/speed-limit boundary.


## DHU AutoDrive simulation repair

- DEV simulator trips now start Android Auto AutoDrive internally when navigation starts; DHU no longer has to deliver `onAutoDriveEnabled()` for simulator playback to begin.
- DEV playback does not subscribe to real phone GPS, preventing real and simulated locations from fighting each other.
- AutoDrive advances by meters along route geometry at a controlled simulated speed instead of one geometry vertex per second.
- AutoDrive owns a dedicated cancellable runnable so repeated host callbacks cannot create parallel simulator loops.
- Production trips keep the normal real-GPS navigation path unchanged.

## Guidance Timing v2

- Ordinary left/right turns no longer force an early prepare prompt; they normally emit approach + now only.
- Approach timing targets roughly 22 seconds before the maneuver, with bounded distance clamps.
- Now timing targets roughly 5.5 seconds before the maneuver, with bounded distance clamps.
- Early prepare is reserved for high-speed driving or complex decisions such as roundabouts, exits, ramps, forks and merges.
- Dart and Android Auto use mirrored timing and prepare-selection rules.
- Regression tests cover ordinary-turn prompt count and complex high-speed prepare behavior.

## Simulator maneuver diagnostics

- Simulator always requests `/api/v1/map/guidance` in addition to `/api/v1/map/route`.
- Route and guidance maneuver streams are scored for semantic richness.
- Richer structured roundabout/exit/ramp/fork/merge semantics are preferred for simulator playback.
- The urban roundabout scenario explicitly reports a routing/provider gap if no roundabout semantic survives either source.
- Production routing behavior is not changed by this simulator-only selection logic.


## Maneuver Intelligence v1.1 – voice regression repair

- Fixes v0.1.93 regression where all sources containing `geometry` were treated as effectively non-actionable.
- Only exact `geometry-emergency` guidance is now forced silent.
- Normalized `geometry` turns remain voice-actionable.
- Structured geometry roundabouts and off-ramps remain voice-actionable.
- Dart and Kotlin regression tests cover both sides of the contract.
- Release verifier now enforces the narrower emergency-only suppression rule.

## Maneuver Intelligence v1

- Uses OSRM-style maneuver categories as the normalization model: turns, ramps, forks, roundabouts and exits are driving decisions; `new_name` and `notification` are informational.
- `continue` is never converted to left/right voice solely from its modifier.
- Geometry-only emergency guidance is non-directional and cannot invent spoken turns from route curvature.
- Structured `on_ramp`, `off_ramp`, `merge`, `fork`, `roundabout` and `end_of_road` semantics get dedicated Norwegian guidance.
- Phone and Android Auto use mirrored actionability rules.
- Added regression tests proving natural geometry turns stay silent while structured decision maneuvers remain actionable.

## Simulator compile repair

- Moved `_routeLength()` into `simulator_models.dart`, the library that actually calls it.
- Removed the now-unused private helper from `simulator_controller.dart`.
- Cleaned the unnecessary string-interpolation analyzer warning.
- Added release-verifier guards so the misplaced helper cannot regress silently.

## Navigation Experience v1.1 – Guidance Semantics & Motion

- Roundabouts no longer fall through to generic slight-left/right instructions when `exit` is missing.
- Motorway `off_ramp` / `exit` maneuvers without exit numbers now say `Ta neste avkjøring` instead of a generic turn.
- Structured maneuver type remains authoritative; instruction text is only an emergency semantic fallback for generic/derived maneuvers.
- Android Auto maneuver icons use the same semantic classification as spoken guidance.
- Phone camera target, heading and zoom are smoothed; camera transitions use longer linear easing for less stop/start motion.
- Active phone navigation now sets Android `FLAG_KEEP_SCREEN_ON`; the flag is cleared when navigation stops, finishes or the screen is disposed.
- Added Dart and native Kotlin behavior tests for roundabout and motorway-exit regressions.

## Gate

This package remains a CI candidate until verifier, Flutter analyze/tests and native app unit tests are all green in GitHub Actions.


## Navigation Simulator Road Network

- Simulator scenarios are resolved through `/api/v1/map/route` before playback.
- Simulated GPS now follows the returned road geometry instead of straight synthetic segments.
- Provider maneuvers are preserved; `/api/v1/map/guidance` enriches routes that lack maneuvers.
- Added dedicated `Motorvei + avkjøring` scenario.
- Fake straight-line simulator rerouting was removed; off-route tests now exercise the normal navigation rerouting path.
- Coarse routing responses are rejected instead of silently producing unrealistic simulation.
- The resolved road-network route is also the route sent to Android Auto / DHU.