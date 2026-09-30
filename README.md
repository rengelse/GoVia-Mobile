# GoVia Mobile v0.1.111+112 – Ferrostar Navigation Core PoC Gate

Release candidate for evaluating Ferrostar Core as a replacement for the duplicated GoVia navigation runtime.

Production navigation behavior remains on the existing GoVia runtime by default. The isolated Ferrostar PoC module is included in the repository and is activated only when `GOVIA_FERROSTAR_POC=1`.

Scope:
- TomTom/GoVia route → Ferrostar Route adapter PoC
- Canonical maneuver mapping including motorway exits and roundabouts
- Provider path-index based speed-limit annotations
- Weak-road-bend suppression in spoken guidance fixtures
- Dedicated Ferrostar PoC GitHub Actions gate
- No server/database changes
- No production runtime switch yet
