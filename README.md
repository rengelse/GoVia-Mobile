# GoVia Mobile v0.1.78+79

Flutter phone app with native Android Auto / AndroidX Car App integration.

Android Auto root: **Turer · Søk destinasjon · Ta opp tur** rendered as a native GoVia grid with host-safe branded icons and GoVia primary color. Turer åpner native faner for **Planlagt · Aktiv · Fullført · Mer**; Mer beholder søk og opptak som sekundære innganger.

Android Auto follows the native AndroidX Car App architecture: session-owned SurfaceRenderer, dedicated foreground navigation service, NavigationManager trip updates and host-owned native templates.
Place search now goes directly to Photon/OpenStreetMap data from both Flutter and Android Auto; GoVia backend is no longer required for address/place lookup.

Navigation foundation: adaptive ETA/progress, route-character preferences, and profile-preserving rerouting on phone and Android Auto.

## Navigation Simulator (development only)

The ordinary GitHub Actions **debug APK** now contains the simulator behind one compile-time `kDebugMode` gate. Open **Profil → Utviklerverktøy → Navigasjonssimulator**. Release builds do not expose the route or menu entry.

The simulator has dedicated routes for normal urban guidance, curvy-road guidance and a stress scenario with GPS jitter/loss, stops, off-route/reroute and arrival. All simulator code remains isolated under `lib/dev/navigation_simulator/` so it can be removed later without touching production navigation logic.

