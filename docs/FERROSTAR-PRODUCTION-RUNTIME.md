# Ferrostar production navigation runtime

GoVia Mobile uses one authoritative navigation runtime: Ferrostar Core 0.53.0. TomTom/GoVia remains the route provider; Flutter and Android Auto are presentation clients of normalized native runtime state.

## Ownership

Ferrostar owns route matching, snapped position, progress, step advancement, arrival and deviation. GoVia owns route-provider I/O, preferences, reroute requests, persistence, POI product behavior and UI. There is no parallel Dart or Kotlin navigation engine.

## Provider contract

Provider maneuvers are required. A maneuver is anchored by an explicit `shapeIndex`/`pathIndex` when available, otherwise only by an exact provider-coordinate match against route geometry. GoVia does not nearest-project maneuvers and does not manufacture directional maneuvers from geometry. Unanchored guidance is rejected.

Speed limits are provider sections anchored by `startPathIndex`/`endPathIndex`. The adapter emits per-segment Ferrostar annotations; unknown segments remain unknown. UI speed-limit signs consume the current Ferrostar annotation.

## Guidance and voice

The route adapter maps provider maneuver semantics into Ferrostar visual/spoken instructions. Weak bends and non-actionable notifications stay silent. Phone and Android Auto deduplicate and render/speak the Ferrostar state; they do not run a second guidance policy.

## Reroute and recovery

Deviation comes from Ferrostar. GoVia performs reroute network I/O and replaces the route atomically with a new Ferrostar session. Android Auto recovery persists route plus the latest fix/progress/arrival metadata; navigation state is rehydrated by the authoritative runtime rather than restoring internal legacy-engine fields.

## Acceptance gate

CI runs Flutter analysis/tests, JVM tests and `FerrostarProductionRuntimeTest` on an Android emulator. The instrumented gate verifies provider maneuver semantics, strict anchoring, speed-limit transitions, snapping/progress/deviation and atomic route replacement. Legacy NavigationCoreV2/GuidanceV1 and Dart NavigationSession files are forbidden by the release verifier.
