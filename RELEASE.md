# GoVia Mobile v0.1.124+125

## v0.1.124 - Ferrostar deviation semantics & deterministic Android gate

- Maps Ferrostar `DeviationKind.CompletelyOffRoute` to GoVia `OFF_ROUTE` and reroute, while `OffStepOnRoute` is `SUSPECT` and does not force a reroute.
- Replaces the far-ahead deviation test point with a lateral ~220 m offset at the current route position so the test exercises deviation detection instead of endpoint snapping/step advancement.
- Repeats GOOD and DEGRADED traces to validate sustained behavior without relying on a single update.
- On any connected Android test failure, CI now prints the generated JUnit XML directly into the Actions log, eliminating blind follow-up releases.
- Extends release preflight to enforce the typed deviation-kind mapping, lateral trace and failure-report contract.

## v0.1.123 - Ferrostar typed deviation runtime hardening

- Replaces fragile `RouteDeviation.toString()` parsing with typed `RouteDeviation.NoDeviation` / `RouteDeviation.Deviation` handling.
- Keeps raw GPS position visible while off-route instead of rendering the snapped route position.
- Makes the production deviation test match Ferrostar 0.53.0 semantics: deviation is computed from the previous navigation state, so the second consecutive good-accuracy off-route fix is the deterministic detection point.
- Verifies sustained off-route state does not immediately clear.


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


## v0.1.119 CI hardening

- Leaves the v0.1.118 Ferrostar production runtime and speed-annotation fix unchanged.
- Enables `/dev/kvm` permissions explicitly on the GitHub Ubuntu runner before AVD launch.
- Pins `ReactiveCircus/android-emulator-runner` to the commit behind release v2.38.0 (`a421e43855164a8197daf9d8d40fe71c6996bb0d`) instead of the floating `@v2` tag.
- Uses an explicit API 35/default/x86_64 AVD profile with 2 cores and 2048 MB RAM.
- Uses a 900-second emulator boot timeout and deterministic no-snapshot/headless emulator options.
- Emits ADB device/state/boot diagnostics immediately before the production runtime test.
- Keeps `FerrostarProductionRuntimeTest` as the acceptance test; no assertions are weakened or bypassed.


## v0.1.120 full preflight and runtime hardening

- Fixes the emulator-runner working-directory bug that caused Gradle to execute from the repository root.
- Uses `working-directory: ./android`; the emulator script no longer relies on `cd`.
- Runs `:app:assembleDebug` and `:app:assembleDebugAndroidTest` before launching the emulator, so packaging/manifest/test-build failures are caught early.
- Adds `tool/ci_contract_verifier.py` and `tool/release_preflight.py`; CI rejects non-persistent `cd`, missing Android working directory, split Gradle commands, invalid local Dart imports, invalid Android XML, Python syntax errors, stale NavigationCoreV2 fixture and version-marker drift.
- Separates terminal arrival verification from deviation/reroute verification so the same completed navigation session is never reused for off-route testing.
- Fixes annotation cardinality for zero-length/same-shape-index provider steps.
- Restricts `roundaboutExitNumber` to roundabout/rotary maneuvers; motorway exit numbers remain in `exits`.
- Removes the unreferenced legacy `test/fixtures/navigation_core_v2_golden.csv` fixture.


## v0.1.121 – Source contract test hardening

- Replaced the brittle single-line `annotationsForStep(stage.speedLimitSections` source assertion with a whitespace-tolerant regex contract.
- No production runtime, route adapter, Flutter application or Android Auto implementation changes.
- Added preflight protection so the obsolete formatting-sensitive assertion cannot be reintroduced.

## v0.1.122 hardening

- Fixes the production Ferrostar deviation accuracy contract: deviation detection now accepts all GoVia `GOOD` GPS fixes (<=25 m), instead of incorrectly suppressing valid 8 m fixes behind a 5 m threshold.
- Keeps the 55 m route-deviation distance threshold unchanged.
- Adds instrumented coverage for both good-accuracy off-route detection and degraded-accuracy suppression.
- Rewrites `tool/release_preflight.py` so source-contract checks execute inside `main()` and contribute to the process exit status. The previous post-`SystemExit` checks were unreachable.
- Keeps the authoritative Ferrostar runtime architecture; no legacy navigation engine is reintroduced.