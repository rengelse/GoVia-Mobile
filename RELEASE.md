# GoVia Mobile v0.1.79+80

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
