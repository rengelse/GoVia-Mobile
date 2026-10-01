# GoVia Mobile v0.1.129+130 – Analyzer Gate Cleanup

- Removes the unused simulator helper that caused `flutter analyze` to fail.
- No production runtime behavior changes from v0.1.128.

## v0.1.128

- Localizes current/next navigation-card instructions from semantic maneuver data on phone.
- Localizes Android Auto Step text through the same navigation-language policy.
- Adds Android TTS service discovery query for reliable speech output.
- Makes simulator scenarios deterministic when the live routing API is unavailable.
- Densifies built-in simulator geometry and assigns explicit Ferrostar shape indexes.
- Anchors live simulator-only provider maneuvers to simulator geometry before strict runtime conversion.
