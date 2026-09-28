# GoVia Mobile v0.1.77+78

## Analyzer cleanup

- Removed an unused simulator import.
- Removed stale `_arrivalFixes` state; arrival confirmation is owned by `GoViaNavigationEngine`.
- Captured the API client before the reroute async gap so navigation no longer uses `BuildContext` after `await`.

## Debug APK simulator integration

- Simulator is now available inside the ordinary GitHub Actions debug APK under Profil → Utviklerverktøy.
- Added one central compile-time `DevFeatures.navigationSimulator = kDebugMode` gate.
- Release builds cannot expose the simulator route or Profile entry.
- Production navigation engine remains independent from simulator UI and synthetic GPS.
- `lib/main_dev.dart` is retained only as a temporary compatibility wrapper; it is no longer required for normal testing.
- Simulator source remains isolated under `lib/dev/navigation_simulator/` for simple removal after development.

## v0.1.75+76 — Navigation Simulator

## Navigation Simulator – development only

- Added a dedicated `lib/main_dev.dart` simulator entrypoint that refuses release mode.
- Added three built-in navigation routes: urban, curvy and stress/off-route.
- Simulator feeds synthetic GPS fixes into the real `NavigationScreen` and `GoViaNavigationEngine`.
- Added controls for 1x/2x/5x/10x, pause, next maneuver, off-route, GPS jitter, GPS loss, stop and arrival.
- Added fake reroute injection so rerouting can be tested without a physical drive.
- DEV routes can be synced to Android Auto for DHU/AutoDrive testing.
- Production `main.dart` and release workflow remain isolated from simulator code.

## v0.1.74+75 — Navigation foundation

- Added a UI-independent phone navigation progress engine with route projection and adaptive ETA.
- Added route-character preferences (motorway/toll/ferry/unpaved/city avoid + scenic/coastal/mountain preferences).
- Planner now sends route profile/preferences with backward-compatible legacy fallback.
- Phone rerouting preserves the selected route profile and preferences.
- Android Auto now detects sustained off-route driving, reroutes after three fixes, preserves route character, and refreshes MapLibre geometry.
- Android Auto ETA now adapts to observed progress and moving speed instead of pure distance ratio.
- Route profile/preferences persist in trip snapshots and the phone/car bridge.

## v0.1.73+74 — Direct place search

- Moves Flutter and Android Auto place/address search off the GoVia backend and directly onto Photon/OpenStreetMap search data.
- Keeps 350 ms type-ahead debounce and six-result limit.
- Adds explicit 8 second HTTP timeouts and GoVia User-Agent headers for direct search requests.
- Improves address labels with street/house number/locality fields from Photon GeoJSON.
- Route calculation is intentionally unchanged in this revision and still uses the existing GoVia route endpoint.

## v0.1.72+73 — Android Auto destination search fix

- Android Auto destination search now uses the same API base URL and signed-in access token synchronized from the phone app.
- Native car API requests now send the same `x-govia-client: mobile` contract as the Flutter `ApiClient`.
- Adds 350 ms input debounce to avoid firing a geocode request on every keystroke.
- Search HTTP failures retain status/body context internally while the car UI keeps a concise error message.

## v0.1.71+72 — Android Auto discovery compatibility

- Adds `android:intentMatchingFlags="allowNullAction"` to `GoViaCarAppService` for Android 16+ Android Auto host binding compatibility.
- Adds regression coverage so the Android Auto discovery compatibility flag cannot silently disappear in later releases.

- Replaces the generic three-row Android Auto home with a native `GridTemplate` for Turer, Søk destinasjon and Ta opp tur.
- Adds a real AndroidX Car App theme with GoVia orange primary/secondary colors, so host UI can carry GoVia branding where supported.
- Tints native GoVia icons through the car theme instead of leaving the host UI visually generic.
- Makes route preview more compact and route-focused, with a primary GoVia-colored Start tur action.
- Applies GoVia color to native navigation information while keeping `NavigationTemplate` and the session-owned MapLibre surface.
- Removes obsolete `GoViaCarCockpitOverlayView.kt` and unused ghost-action compatibility code; no custom cockpit overlay is reintroduced.
- Keeps the phone/car process isolation, native Android Auto lifecycle and four-tab trip architecture unchanged.

Version: **0.1.71+72**

## v0.1.69+70 — Android Auto native GoVia visual pass

- Restores a native GoVia home screen with Turer, Ta opp tur and Søk destinasjon.
- Keeps Android Auto state isolated from phone UI and preserves the single session-owned MapLibre surface.
- Refines native trip tabs, rows, preview metadata and navigation actions to match the locked GoVia visual direction as closely as Android Auto templates allow.
- Uses host-owned app branding through Action.APP_ICON and existing GoVia launcher assets; no generic navigation-arrow branding is introduced.

## Android Auto – Kotlin compile + release-marker fix

- Fixed `GoViaCarMapSurface.updateRoute()` to call the map-only `drawRoute()` signature without an obsolete argument.
- Moved `GoViaCarSearchScreen` cleanup onto the AndroidX lifecycle observer (`onDestroy(LifecycleOwner)`) instead of overriding a non-existent `Screen.onDestroy()`.
- Preserves the v0.1.65 native Android Auto architecture rewrite and v0.1.66 test contract updates.
- Android for Cars static contract verifier: PASS.

## Android Auto – native specification architecture

- Reworked the Android Auto layer against the AndroidX Car App navigation model instead of a custom cockpit UI stack.
- `GoViaCarSession` owns one `GoViaCarRuntime` and one persistent MapLibre surface renderer for the full car session.
- Added dedicated `GoViaNavigationService` in the car process for location, route progress, maneuver state, TTS/audio focus, foreground navigation state and `NavigationManager` integration.
- Active navigation now uses native `NavigationTemplate`, `RoutingInfo`, `TravelEstimate`, native action strip and native map action strip.
- Navigation lifecycle now calls `navigationStarted()`, continuous `updateTrip(...)`, and `navigationEnded()`.
- Added navigation foreground notification with `CarAppExtender` and navigation category.
- Added `onAutoDriveEnabled()` support for Android Auto review/simulation.
- Map Surface is map-only; custom cockpit controls/ghost action workarounds are no longer rendered over host UI.
- Trip overview uses native `TabTemplate` with four tabs: Planlagt, Aktiv, Fullført and Mer. Mer contains Søk destinasjon and Ta opp tur.
- Route preview uses `MapWithContentTemplate` on Car API 7+ with a native Pane fallback on older hosts.
- Recording ready uses native `PaneTemplate`; recording map uses native map/content template on supported hosts.
- Destination search remains native `SearchTemplate` and routes into the same preview/navigation flow.
- Navigation intents support both query-style `geo:0,0?q=...` and direct coordinate `geo:lat,long` destinations.
- Location permission can be granted from the car host while parked, following the AndroidX navigation sample pattern.
- `androidx.car.app.action.NAVIGATE`, `android.intent.action.NAVIGATE`, and `VIEW geo:` intent filters are declared.
- Existing process-safe phone/car snapshot bridge is retained for shared domain data; phone UI notifications do not drive car rendering.

Version: **0.1.69+70**