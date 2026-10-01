# GoVia Mobile v0.1.118+119 — Ferrostar Speed Annotation Alignment Fix

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
- Removes the stale Android Auto speed-limit test assertion tied to the retired pre-Ferrostar service-owned speed matcher.
- Verifies the production speed-limit chain instead: provider path sections → Ferrostar route annotations → Ferrostar runtime state → navigation service → Android Auto map surface.
- Removes the unused simulator model import so `flutter analyze` is clean again.

- Fixes production speed-limit annotation indexing: annotation arrays now match RouteStep geometry coordinate counts exactly, including step-boundary coordinates.
- Strengthens the Android emulator acceptance test with dense route fixes, explicit 80→60→40 ordering, and annotation/geometry cardinality checks.
