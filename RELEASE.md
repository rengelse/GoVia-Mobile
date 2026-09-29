# GoVia Mobile v0.1.83+84

## Navigation Core v2

- Added canonical `NavigationRoute` and explicit `NavigationSession` on phone.
- Added native `NavigationCoreV2` for Android Auto with the same route/session contract.
- Active navigation now owns exactly one Stage; Android Auto no longer flattens a multi-stage trip into one runtime geometry.
- Maneuvers are anchored to canonical route geometry instead of trusting backend `distanceFromStartMeters` for progression.
- Route matching now uses continuity, heading and GPS accuracy, with protection against false backward/forward jumps.
- Off-route detection, adaptive ETA, maneuver progression and three-fix arrival detection are owned by Navigation Core v2.
- Poor-accuracy GPS fixes cannot advance navigation progress.
- Phone navigation requires guidance before activating the session and persists the enriched route back into the active Stage.
- Phone reroutes replace the active runtime route without turning `Trip` into navigation state.
- Android Auto bridge schema upgraded to v3 and now preserves maneuver type, modifier, road ref, duration, exit, source and confidence.
- Android Auto uses structured maneuver metadata instead of parsing Norwegian instruction text to infer turn type.
- Geometry-derived Android Auto maneuvers remain only as an emergency fallback for legacy geometry-only snapshots.
- Android Auto foreground navigation service is now started + bound, uses `START_STICKY`, and can rehydrate the selected active trip/stage after process restart.
- Android Auto now exposes explicit arrival state and destination guidance.
- Added native Kotlin Navigation Core v2 unit tests and CI execution via `testDebugUnitTest`.
- Added Dart behavioral tests for maneuver anchoring, GPS quality, progress, off-route state and arrival.
- Updated static verifier for Navigation Core v2 ownership and contracts.

## Analyzer-clean test hardening

- Fixed `prefer_single_quotes` in `test/place_search_hardening_test.dart`.
- Added verifier coverage for the exact stale double-quote regression in the place-search hardening test.
- No navigation behavior changes.

- Ordinary Android Auto routes initialize the first maneuver immediately.
- Geometry-only routes receive deterministic fallback guidance so NavigationTemplate cannot remain in endless loading.
- NavigationTemplate has a defensive non-loading `Følg ruten` state whenever active navigation lacks maneuver metadata.
- Phone and Android Auto place search remove Photon `lang=no` and request Norwegian with `Accept-Language`.
- Android Auto search adds current-location bias when a last known position is available.

## Development simulator activation + route-map test hardening

- The single signed GitHub release APK now explicitly enables `GOVIA_NAV_SIMULATOR=true` during active development.
- `Profil → Utviklerverktøy → Navigasjonssimulator` is therefore available in the APK installed from GitHub Releases.
- Final production builds can remove the simulator by omitting the one build define; the default remains disabled.
- Route-map remount identity is now a pure, directly tested helper instead of a brittle source-string assertion.
- Route geometry and visible waypoint changes both alter the render key and force a fresh map surface.

## Multi-stage canonical trip foundation

- Mobile trip model now carries per-stage status, name and stage-owned via points, stops and POI.
- Desktop handoff reader accepts both legacy `snapshot.stages` and canonical nested `snapshot.trip.stages`.
- Canonical route candidates preserve geometry, maneuvers, route profile and route preferences.
- Mobile trip detail sends multi-stage trips to an explicit stage picker instead of automatically starting stage 1.
- Any navigable stage can be started directly, completed independently and driven again later.
- Completing a non-final stage keeps the trip active and offers the next stage.
- Imported stage POI/stops/via points are rendered on the mobile route map and retained in local snapshots.
- Android Auto receives the same stage-owned metadata and offers an explicit stage selector for multi-stage trips.
- Android Auto navigation is started with only the selected stage, preventing accidental navigation across the whole multi-stage itinerary.
- Stage-owned POI are preferred for Android Auto approach alerts, with legacy global POI retained as fallback.


## Navigation test hardening

- Updated stale navigation source-contract tests after route matching and arrival ownership moved into `GoViaNavigationEngine`.
- Added behavioral tests proving arrival requires three consecutive credible GPS fixes.
- Added a behavioral reset test proving two arrival fixes are discarded after moving clearly away from the destination.
- Added verifier guards so the old `_matchToRoute`, `_distanceFromRoute`, and screen-owned arrival assertions cannot silently return.
