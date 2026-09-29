# GoVia Mobile v0.1.89+90 CI Candidate

## Guidance v1 CI repair

- Removed the stale `_startAnnouncementSpoken` reference that broke `flutter analyze` and `:app:compileFlutterBuildDebug`.
- Fixed next-maneuver formatting so only the sentence-leading verb is lowercased; route refs/names such as `E39 Bergen` retain their case.
- Added a static verifier guard that forbids the obsolete startup-announcement symbol from returning.
- Added an explicit Guidance v1 policy with `prepare → approach → now` phases on phone and Android Auto.
- Guidance distance adapts to current speed instead of fixed 650/220/55 metre buckets.
- Voice deduplication is keyed by maneuver ID + phase and survives runtime recovery.
- Structured maneuver fields drive roundabout exits, motorway exits and road reference/name formatting before falling back to provider instruction text.
- Phone navigation now shows the next maneuver as a `Deretter …` preview.
- Android Auto re-synchronizes `NavigationManager` when the car host attaches to an already-running navigation session.
- Android Auto always publishes an active fallback Step before the first valid maneuver/GPS fix so DHU guidance does not disappear during startup.
- Removed the competing generic Android Auto startup utterance that could be interrupted by the first `QUEUE_FLUSH` maneuver. TTS readiness is explicit and the first useful maneuver cue has priority.
- Android Auto voice preference is restored from the phone/car bridge when navigation starts.
- Added Guidance v1 behavior tests, standalone Kotlin smoke coverage and a dedicated acceptance specification.

## Navigation Core v2 Cleanup & Runtime Hardening

- Removed `navigation_engine.dart` and migrated its remaining behavior coverage directly to `NavigationSession` tests.
- `ARRIVED` is terminal for the active Stage until navigation stops or a new Stage starts.
- Stale/out-of-order GPS fixes are rejected before they can change progress, ETA, matching or arrival state.
- Poor/unknown accuracy fixes cannot initialize route progress or arrival state.
- Android Auto AutoDrive now emits explicit good simulated GPS accuracy.
- Rerouted stage waypoints/POI are reprojected onto the replacement route geometry.
- Reroute results are accepted only when Trip ID, Stage ID, route ID and session revision still match the request origin.
- Android Auto persistence now stores route data only when the route changes and throttles the small runtime snapshot to five-second intervals plus important transitions.
- Dart `NavigationSession.replaceRoute()` enforces immutable Stage identity, matching the native core invariant.
- Added behavior tests for terminal arrival, stale fixes, poor first fix, waypoint reprojection and stale reroute rejection.
- Removed verifier dependence on the deleted legacy engine and updated stale release documentation.


## Navigation Core v2 Hardening

- Android Auto screen/lifecycle reattach now attaches to an existing matching Trip+Stage session instead of resetting progress and guidance state.
- Stage identity is stable across reroutes; native `CarStage.routeId` tracks route identity independently.
- Android Auto reroutes retain stage name/status, route preferences and stage-owned waypoints/POI.
- `car_active_stage_id` is persisted independently from selected Trip ID.
- Android Auto persists a NavigationSession v2 snapshot including progress, matched segment, maneuver index, off-route/arrival counters, ETA continuity inputs and reroute state.
- Sticky process recovery rehydrates the persisted active/rerouted Stage and restores Navigation Core continuity before accepting new GPS fixes.
- Android Auto binding/preparation no longer starts the foreground service; foreground navigation starts only when navigation begins or Android restarts an active sticky service.
- Maneuver anchoring is monotonic and uses expected route progress to disambiguate repeated coordinates, loops and crossing geometry.
- Unknown/invalid GPS accuracy is conservative and cannot advance route state or trigger arrival.
- Android Auto reroute state moved into `NavigationCoreV2` (`CarRerouteState`), removing the parallel service-owned rerouting boolean.
- Added behavior tests for loop anchoring, unknown GPS, session snapshot recovery, screen reattach identity, preferred-stage recovery and reroute metadata/POI retention.
- Replaced brittle source-string Navigation Core tests with executable Dart behavior tests.
- Updated stale implementation-status documentation to the current Android Auto/Navigation Core v2 architecture.

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

- Navigation behavior coverage targets `NavigationRoute` + `NavigationSession` directly; the obsolete engine facade is removed.
- Behavioral tests cover credible arrival, terminal arrival, stale fixes, GPS quality, route progress and off-route state.
- Verifier guards prevent the deleted legacy navigation-engine facade from returning.
