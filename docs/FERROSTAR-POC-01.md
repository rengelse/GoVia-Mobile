# GoVia Ferrostar PoC-01 — canonical route adapter gate

## Scope

This PoC is deliberately isolated from production runtime. It does **not** replace `NavigationSession`,
`NavigationCoreV2`, phone navigation, Android Auto, voice, rerouting, or recording.

It answers one question first:

> Can GoVia's provider-authoritative TomTom route data be represented directly in Ferrostar's core
> route model without re-introducing geometry heuristics?

## Why this gate exists

The current GoVia runtime duplicates route matching and progress logic in Dart and Kotlin. Speed-limit
selection and maneuver progression then depend on which runtime matched the current geometry segment.
Before replacing either runtime, the input contract must be clean.

Ferrostar `Route` is compatible with what GoVia needs:

- route geometry
- per-step geometry
- maneuver type/modifier
- visual instructions
- spoken instructions
- per-segment annotations
- waypoints

The PoC maps TomTom speed limits to per-segment annotations and maps canonical TomTom maneuver
semantics (`off_ramp`, `roundabout`, `merge`, etc.) directly to Ferrostar maneuver types.

## Hard contract discovered by the PoC

GoVia currently serializes TomTom maneuvers with `routeOffsetInMeters` and maneuver coordinates, but not
with a provider-authoritative path/shape index. The production adapter must **not** recover that index by
nearest-point matching.

Before production migration, the server canonical route should expose a field such as:

```json
{
  "type": "off_ramp",
  "modifier": "right",
  "distanceFromStartMeters": 2100,
  "shapeIndex": 842
}
```

`shapeIndex` should be derived on the server from TomTom route progress/path data. This keeps TomTom's
route coordinate space authoritative for:

1. maneuver anchoring,
2. speed-limit section anchoring,
3. the Ferrostar step model.

## Acceptance cases in this PoC

1. `off_ramp/right` remains an explicit OFF_RAMP maneuver.
2. roundabout + exit number survives conversion.
3. weak `turn/slight_right` does not become a spoken event.
4. speed limits are attached by provider path index.
5. unknown speed-limit segments remain unknown; no carry-forward guessing.
6. an unanchored maneuver is rejected instead of being projected heuristically.

## Running

The module is included only when `GOVIA_FERROSTAR_POC=1`.

```bash
cd android
GOVIA_FERROSTAR_POC=1 gradle :ferrostar-poc:testDebugUnitTest
```

A dedicated `Ferrostar PoC Gate` GitHub Actions workflow performs the same check.

## Next gate (PoC-02)

Only after PoC-01 compiles against the real Ferrostar AAR:

- add a simulated Ferrostar navigation session;
- replay a fixed trace through Ferrostar and current GoVia core side-by-side;
- compare snapped position, step, progress, deviation, and speed-limit annotation;
- no production runtime replacement until the acceptance trace is green.
