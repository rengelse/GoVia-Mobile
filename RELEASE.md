# GoVia Mobile v0.1.116+117 — Ferrostar Authoritative Navigation Runtime – Android 7.1 Compatibility Baseline

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

- Enables Android core library desugaring and adds `desugar_jdk_libs` required by Ferrostar Core 0.53.0.
- Adds a static CI contract check so the required desugaring configuration cannot silently regress.
- Raises Android minSdk from 24 to 25, matching Ferrostar Core 0.53.0's declared minimum API level.
- Adds a static CI contract check requiring minSdk >= 25; no `tools:overrideLibrary` compatibility bypass is used.
