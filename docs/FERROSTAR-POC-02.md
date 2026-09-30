# Ferrostar PoC-02 — Runtime Comparison Gate

## Purpose

PoC-02 moves beyond the adapter-only compile gate from v0.1.109. It runs one provider-anchored canonical route through both:

1. the production `NavigationCoreV2`, and
2. a real Ferrostar `NavigationSession` created by `FerrostarSessionBuilder`.

The PoC remains test-only. It is not referenced by the production application runtime.

## Acceptance scenarios

- monotonic route progress on the same GPS trace;
- Ferrostar snapped position is available while navigating;
- provider speed-limit annotations reach Ferrostar runtime state;
- motorway exit remains an explicit actionable maneuver;
- weak road bend remains silent;
- GPS jump does not move GoVia progress backwards and can be inspected against Ferrostar deviation/snapping state.

## Deliberate limits

- no production runtime switch;
- no phone UI changes;
- no Android Auto changes;
- no TTS replacement;
- no server/schema changes;
- no automatic reroute integration.

The next gate is allowed only after the runtime comparison test compiles and passes in GitHub Actions.
