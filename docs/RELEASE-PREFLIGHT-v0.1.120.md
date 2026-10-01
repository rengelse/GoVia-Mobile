# GoVia Mobile v0.1.120 release preflight

This release was audited end-to-end after repeated CI failures.

## CI/workflow
- Android emulator runner pinned to an immutable v2.38.0 commit.
- KVM explicitly enabled and verified.
- Emulator uses API 35/default/x86_64 with fixed resources and boot timeout.
- Emulator action uses `working-directory: ./android`; no `cd android` state dependency remains.
- Instrumented Gradle command is one shell command.
- `:app:assembleDebug` and `:app:assembleDebugAndroidTest` run before emulator launch.
- ADB state and boot completion are verified using the action-provided emulator port.

## Repository/static integrity
- All local Dart imports/exports resolve to existing files.
- All Android XML files parse.
- Kotlin package paths match their declared packages.
- Android manifest component classes resolve to production Kotlin classes.
- All Python release tools compile.
- No zero-byte source/config files were found.
- Version markers are synchronized at `0.1.120+121`.
- Legacy NavigationCoreV2/GuidanceV1/Dart NavigationSession files and the stale NavigationCoreV2 golden fixture are absent.

## Ferrostar/runtime
- Core library desugaring and `desugar_jdk_libs` remain enabled.
- minSdk remains 25, matching Ferrostar Core 0.53.0.
- Provider maneuvers remain strictly shape-index/exact-coordinate anchored.
- Speed-limit annotations are coordinate-aligned with Ferrostar RouteStep geometry, including duplicate provider shape-index steps.
- `roundaboutExitNumber` is emitted only for actual roundabout/rotary maneuvers.
- Arrival and deviation/reroute acceptance scenarios use separate Ferrostar sessions because arrival is terminal.
- Runtime acceptance still validates progress, snapping, 80→60→40 speed-limit order, arrival, deviation, atomic reroute, provider semantics and weak-bend voice suppression.

## Packaging
- FULL release ZIP must contain the workflow, preflight tools, authoritative runtime, route adapter and Android instrumented runtime test.
- UPDATE release removes the retired `test/fixtures/navigation_core_v2_golden.csv` fixture.

Dynamic Flutter/Gradle/device execution remains the final GitHub CI gate; the release is not declared runtime-green until that gate passes.
