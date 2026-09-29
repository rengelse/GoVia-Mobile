# GoVia Mobile implementation status – v0.1.86+87

## Production-connected
- Supabase shared authentication with GoVia Desktop.
- GoVia routing/roundtrip APIs and direct Photon/OpenStreetMap place search.
- Canonical multi-stage Trip/Stage model with explicit stage selection.
- Desktop → Mobile handoff foundation with route geometry, maneuvers, route profile/preferences and stage-owned via/stops/POI.
- GPS/TTS phone navigation using Navigation Core v2.
- Native Android Auto / AndroidX Car App integration with MapLibre map surface and host-owned NavigationTemplate UI.
- Android Auto Navigation Core v2 with one active Stage, structured maneuver guidance, ETA/progress/off-route/arrival state and rerouting.
- Android Auto foreground navigation lifecycle with process recovery of trip, active Stage, active/rerouted route and NavigationSession progress state.
- Route recording foundation, Discover/community routes, trip chat, profile/history, weather/POI and offline-map foundation.

## Navigation Core v2 hardening status
- Stage identity remains stable across reroutes; route identity changes independently.
- Reroutes retain Stage metadata and waypoints/POI.
- Screen reattach no longer recreates/reset an already active Android Auto navigation session.
- Active Stage ID and NavigationSession snapshot are persisted separately from Trip identity.
- Sticky process recovery restores progress, matched segment, maneuver index and route continuity state.
- Binding/preparing Android Auto no longer starts a foreground navigation notification; foreground service starts only for active navigation/recovery.
- Maneuver anchors are monotonic and use expected route progress to disambiguate repeated coordinates/loops/crossing geometry.
- Unknown GPS accuracy is conservative and cannot advance progress or trigger arrival.
- Poor/unknown GPS accuracy is conservative even on the first fix and cannot initialize progress or arrival.
- Arrival is terminal for the active Stage; later GPS fixes cannot reopen navigation state.
- Out-of-order/stale GPS timestamps are rejected before progress, ETA or matching can change.
- Rerouted Stage POI/waypoints are reprojected onto the replacement geometry before proximity alerts resume.
- Android Auto reroute responses are guarded by Trip ID + Stage ID + route ID + session revision.
- Route persistence occurs only at route/session changes; lightweight runtime snapshots are throttled between important transitions.
- Android Auto reroute state is owned by Navigation Core v2 rather than a parallel service boolean.
- Core behavior tests cover arrival, off-route, poor/unknown GPS, loop anchoring, reattach identity, stage selection, reroute metadata and session snapshot recovery.

## Development-only
- `Profil → Utviklerverktøy → Navigasjonssimulator` is enabled in development release APKs by `GOVIA_NAV_SIMULATOR=true`.
- Simulator remains compile-time removable for production.

## Still pending / later phases
- Choice and integration of a mature low-level routing/guidance provider (for example Valhalla or equivalent) behind the GoVia provider abstraction.
- Full offline route calculation/guidance package contract.
- Lane guidance and richer provider-native motorway/roundabout metadata where available.
- CarPlay implementation.
- Permanent live-group GPS sharing and push/device backend contract.

## Architecture rule
GoVia Trip/Stage/POI remain product-domain data. Active navigation owns exactly one Stage through a canonical NavigationRoute/NavigationSession. A reroute replaces the active route; it does not create a new Stage or mutate the Trip into runtime state.
