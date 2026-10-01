# GoVia Mobile v0.1.126+127 – Navigation Simulator, Voice Language & Trip Completion Flow


GoVia Mobile now uses Ferrostar Core as the single authoritative navigation runtime for phone and Android Auto. TomTom/GoVia remains the route provider. Progress, snapping, step advancement, arrival, deviation, speed-limit annotations and spoken maneuver state are produced by the same native runtime.

Release v0.1.125 fixes the Android emulator workflow after v0.1.124 proved the Ferrostar instrumented runtime suite itself was green. The emulator-runner executes each `script:` line in a separate shell, so multiline `if ... fi` diagnostics cannot live inside that action script. The runtime command is now a single failing/passing command, while JUnit XML/report dumping runs in a normal post-failure GitHub Actions step.


Legacy Dart NavigationSession, Kotlin NavigationCoreV2 and GuidanceV1 implementations have been removed rather than retained as fallbacks. Provider maneuvers are strictly anchored; unknown speed limits remain unknown.

See `docs/FERROSTAR-PRODUCTION-RUNTIME.md` for the production contract and CI gates.


Android production builds explicitly enable core library desugaring required by Ferrostar Core 0.53.0.

Ferrostar Core 0.53.0 requires Android API 25. GoVia Mobile therefore uses minSdk 25 as the production compatibility baseline; no manifest override is used.

The v0.1.118 gate also aligns the Android Auto speed-limit contract test with the authoritative Ferrostar pipeline and removes the final navigation-simulator analyzer warning.


The v0.1.118 runtime fix aligns every Ferrostar speed-limit annotation one-to-one with RouteStep geometry coordinates, including step boundaries, so `currentStepGeometryIndex` always addresses valid provider metadata.


The v0.1.119 CI gate hardens the Linux Android emulator environment with explicit KVM permissions, a release-commit-pinned emulator runner, deterministic AVD resources/options, extended boot timeout and ADB diagnostics. Production navigation/runtime code is unchanged from v0.1.118.


The v0.1.120 gate fixes the emulator working-directory contract by using the action's explicit `working-directory: ./android` input and a single Gradle command, adds an Android APK/androidTest package preflight before emulator launch, and introduces static release/CI verifiers. The Ferrostar production test now validates arrival and deviation in separate navigation sessions. The route adapter also preserves annotation/geometry cardinality for duplicate provider shape indexes and limits roundabout exit metadata to actual roundabouts.

## v0.1.122 runtime hardening

Ferrostar deviation detection is aligned with GoVia GPS quality: all `GOOD` fixes (<=25 m accuracy) are eligible for route-deviation checks, while degraded fixes remain protected from false off-route signals. Release preflight source-contract checks are now executable and release-blocking rather than unreachable after process exit.
