# GoVia Mobile v0.1.85+86

Navigation Core v2 replaces the old split runtime model with an explicit canonical route/session architecture. Phone navigation now uses `NavigationRoute` + `NavigationSession`; Android Auto uses the equivalent native `NavigationCoreV2`, and both enforce exactly one active Stage per navigation session.

v0.1.85 removes the obsolete navigation-engine compatibility facade and hardens runtime behavior: arrival is terminal, stale GPS fixes are rejected, poor first fixes cannot move state, AutoDrive supplies credible simulated accuracy, rerouted POI are reprojected onto the new geometry, stale reroute results are guarded by Trip+Stage+route+revision identity, and Android Auto route persistence is separated from throttled runtime snapshots.

v0.1.85 hardens that foundation: Android Auto screen reattach preserves the active session, Stage and route identity are separated during reroute, stage POI/waypoints survive rerouting, active Stage + NavigationSession progress are persisted for process recovery, bind-only Android Auto startup no longer creates a foreground notification, loop/crossing maneuver anchoring is monotonic, and unknown GPS accuracy is handled conservatively.

Core v2 anchors maneuvers to route geometry, uses GPS accuracy/heading/continuity in matching, owns progress/ETA/off-route/arrival state, preserves the full maneuver model across the phone→car bridge, and keeps geometry-derived guidance only as an emergency fallback for legacy snapshots. Android Auto navigation is now a started foreground service with sticky recovery of the selected active trip/stage.

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

