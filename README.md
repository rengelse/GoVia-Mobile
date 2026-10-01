# GoVia Mobile v0.1.129+130 – Analyzer Gate Cleanup

## v0.1.129

This maintenance release removes the unused `_pointAtDistance` helper left behind by the v0.1.128 simulator refactor. No production navigation, voice, localization, completion-flow, Ferrostar runtime, or simulator behavior is changed.

## v0.1.128

This release fixes three runtime regressions found after v0.1.127:

- Navigation cards now render semantic instructions in the selected navigation language instead of raw provider instruction text. The same policy is used by phone and Android Auto.
- Android declares the TTS service query required for reliable speech-engine discovery on current Android versions. Navigation TTS continues to use semantic GoVia localization.
- The navigation simulator no longer depends on a successful live routing request. Built-in scenarios are densified and carry explicit Ferrostar shape indexes; live provider maneuvers are normalized to simulator geometry before entering the strict production adapter.

The Ferrostar production runtime and strict production maneuver anchoring remain unchanged.
