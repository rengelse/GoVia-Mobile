# GoVia Mobile v0.1.65+66

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

Version: **0.1.65+66**
