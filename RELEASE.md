# GoVia Mobile v0.1.109+110 — Ferrostar Navigation Core PoC Gate

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
