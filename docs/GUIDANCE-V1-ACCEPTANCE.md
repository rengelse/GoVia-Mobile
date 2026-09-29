# Guidance v1 Acceptance

Guidance v1 is a navigation-experience layer on top of Navigation Core v2. Navigation Core remains the authority for route matching, maneuver progression, ETA, off-route state, rerouting and terminal arrival.

## Required behavior

1. Guidance uses explicit `prepare`, `approach`, and `now` phases.
2. Phase distance adapts to current speed instead of fixed 650/220/55 metre buckets.
3. Voice deduplication is keyed by maneuver ID + guidance phase.
4. Structured maneuver fields (`type`, `modifier`, `exit`, `roadName`, `roadRef`) are preferred over instruction-text parsing.
5. Roundabout exit numbers are spoken and displayed when present.
6. Road reference/name fallback is deterministic.
7. Phone shows current maneuver plus next-maneuver preview.
8. Android Auto `NavigationTemplate` and `NavigationManager` are fed from the same active navigation state.
9. Reattaching Android Auto to an already-running navigation session re-announces navigation to the host and pushes current trip metadata.
10. Android Auto always supplies a fallback active Step to `NavigationManager` before a valid maneuver/GPS fix exists, so DHU guidance does not disappear during startup.
11. TTS does not play a generic startup utterance that can be cut off by the first maneuver. The first useful maneuver cue is prioritized.
12. TTS readiness is explicit; maneuver announcements are not marked delivered before the TTS engine is initialized.
13. Spoken phase keys are persisted with navigation runtime state so process recovery does not replay already-spoken phases arbitrarily.
14. Reroute resets guidance dedupe for the replacement active route.
15. Poor/stale GPS must not advance Navigation Core, and therefore must not advance guidance.
16. Lane guidance remains out of scope until real lane metadata exists in the routing contract.

## Gates

- `python3 tool/verify_mobile.py`
- `bash tool/navigation_core_kotlin_smoke.sh`
- `bash tool/navigation_guidance_kotlin_smoke.sh`
- `flutter analyze`
- `flutter test`
- Android `:app:testDebugUnitTest`

The local acceptance script runs all available gates and reports Flutter/Gradle as blocked rather than pretending they passed when the SDK/toolchain is unavailable.
