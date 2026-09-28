# GoVia Mobile v0.1.80+81

Development GitHub release APKs expose `Profil → Utviklerverktøy → Navigasjonssimulator`. The feature is controlled by the single compile-time define `GOVIA_NAV_SIMULATOR`; its default is off so the final production build can remove the developer surface without changing navigation logic.

Flutter phone app with native Android Auto / AndroidX Car App integration.

Current mobile trip contract supports multi-stage trips, explicit stage selection, per-stage progress, route geometry, maneuvers, via points, stops and POI for Desktop handoff compatibility.

Android Auto root: **Turer · Søk destinasjon · Ta opp tur** rendered as a native GoVia grid with host-safe branded icons and GoVia primary color. Turer åpner native faner for **Planlagt · Aktiv · Fullført · Mer**; Mer beholder søk og opptak som sekundære innganger.

Android Auto follows the native AndroidX Car App architecture: session-owned SurfaceRenderer, dedicated foreground navigation service, NavigationManager trip updates and host-owned native templates.
Place search now goes directly to Photon/OpenStreetMap data from both Flutter and Android Auto; GoVia backend is no longer required for address/place lookup.

Navigation foundation: adaptive ETA/progress, route-character preferences, and profile-preserving rerouting on phone and Android Auto.

## Navigation Simulator (development only)

The single GitHub APK used during development enables the simulator with the compile-time define `GOVIA_NAV_SIMULATOR=true`. Open **Profil → Utviklerverktøy → Navigasjonssimulator**. The feature defaults to disabled, so the final production build removes the developer surface simply by omitting that one define.

The simulator has dedicated routes for normal urban guidance, curvy-road guidance and a stress scenario with GPS jitter/loss, stops, off-route/reroute and arrival. All simulator code remains isolated under `lib/dev/navigation_simulator/` so it can be removed later without touching production navigation logic.

