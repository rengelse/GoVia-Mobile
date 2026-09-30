# GoVia Mobile v0.1.113+114 — Ferrostar Migration Decision Gate

- Extends the green Android instrumented Ferrostar comparison into a migration decision gate.
- Verifies provider-anchored speed-limit transitions at 80 → 60 → 40 km/h against Ferrostar runtime annotations.
- Keeps weak bends silent while preserving motorway exits and roundabout semantics.
- Records side-by-side GoVia/Ferrostar runtime samples as a JSON artifact for review.
- Keeps all production navigation code unchanged; Ferrostar remains instrumented-test-only.

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

## v0.1.112 runtime-gate correction

- Moves `FerrostarRuntimeComparisonTest` from local JVM tests to Android instrumented tests.
- Adds `AndroidJUnitRunner` and instrumented-test-only Ferrostar dependencies.
- Runs the side-by-side GoVia/Ferrostar runtime comparison on an Android x86_64 emulator.
- Keeps Ferrostar out of the production APK dependency graph.
- Production navigation source is unchanged.
