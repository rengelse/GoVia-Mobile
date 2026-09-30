# GoVia Mobile v0.1.111+112 — Ferrostar Navigation Core PoC Gate

- Fixes the v0.1.110 PoC runtime comparison build contract: the `:ferrostar-poc` module is now always visible to Gradle but remains test-only for `:app`.
- Exposes Ferrostar Core transitively from the PoC module so the app-side comparison test can compile against `Route`, `TripState`, `UserLocation`, and related UniFFI types.
- Synchronizes pubspec, README and RELEASE version markers.
- Production navigation runtime remains unchanged.

- Adds an isolated Ferrostar Core 0.53.0 proof-of-concept module for navigation-runtime evaluation.
- Keeps the current GoVia production navigation runtime unchanged unless `GOVIA_FERROSTAR_POC=1` is explicitly enabled.
- Adds TomTom/GoVia → Ferrostar route mapping fixtures for motorway exits, roundabouts, guidance and provider-anchored speed limits.
- Adds a dedicated GitHub Actions PoC gate.
- No server, database or Supabase changes.

## v0.1.110 – Ferrostar Runtime Comparison PoC

- Adds a test-only side-by-side runtime gate between production `NavigationCoreV2` and a real Ferrostar `NavigationSession`.
- Sends the same provider-anchored route and GPS trace through both runtimes.
- Verifies monotonic progress, snapped position, provider speed-limit annotations, motorway-exit semantics, weak-bend suppression and GPS-jump behavior.
- Keeps Ferrostar outside production runtime; no phone UI, Android Auto, routing provider or server contract is switched in this release.
