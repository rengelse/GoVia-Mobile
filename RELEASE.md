# GoVia Mobile v0.1.114+115 — Ferrostar Authoritative Navigation Runtime

- Promotes Ferrostar Core 0.53.0 from PoC to the production navigation runtime.
- Uses one native runtime for phone and Android Auto route progress, snapped position, step advancement, arrival and deviation.
- Removes legacy Dart NavigationSession and native NavigationCoreV2/GuidanceV1 implementations completely.
- Uses provider maneuver semantics only; no geometry-derived guidance fallback and no nearest-point maneuver guessing.
- Carries provider shape/path indexes through the mobile route contract and rejects unanchored guidance.
- Feeds provider speed-limit path sections into Ferrostar annotations and renders the active limit from runtime state.
- Uses Ferrostar spoken instructions for maneuver voice with weak bends/non-actionable events kept silent.
- Performs reroute I/O in GoVia and atomically replaces the Ferrostar session.
- Adds one production Android-emulator acceptance gate and removes the separate PoC workflow/module.
- Keeps ride recording separate from navigation-runtime ownership.
