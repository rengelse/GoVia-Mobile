## v0.1.21 — Discover Detail Analyzer Hotfix

- Rewrote the community route detail screen with explicit, valid Dart structure.
- Fixed the tags section bracket error that prevented Flutter analysis/compilation.
- Replaced invalid `GoViaColors.accent` references with the existing GoVia orange token.
- Removed the redundant `geolocator_android` import from navigation.
- Added braces to the remaining analyzer-reported profile flow control.
- No runtime feature scope, backend contract or database migration changed.

## v0.1.20 — Publish Your Route

- Publish a real planned/active/completed GoVia stage as an immutable community snapshot.
- Added source selection across actual trips/stages; ferry-only stages are excluded as primary published routes.
- Added title, description, transport-aware tags, visibility and preview-before-publish flow.
- Added cover image selection, multi-image upload and editing/removal of existing route photos.
- Added My Published Routes with edit, unpublish, republish and delete actions.
- Existing community route editing never mutates the private source trip.

## v0.1.19 — Discover Phase 3: Route Detail, Ratings & Elevation

- New visual community route detail with map, media, attributes and action buttons.
- Community rating with Experience, Scenery and transport-aware Road/Surface/Comfort scores.
- Real elevation profiles from GoVia API using Open-Meteo / Copernicus DEM GLO-90.
- Saved route and Drive Route actions stay connected to the existing GoVia trip/navigation flow.

# GoVia Mobile v0.1.18 – Discover Local & Global Routes

- Redesigned Discover overview with Mine turer, Nær meg and Globalt sections.
- Nearby routes use the device position and real published-route geometry.
- Added transport, route-length, duration and photo filters.
- Ferry is no longer exposed as a primary Discover transport.
- Community cards use real published photos with map fallback; no production demo routes.
- No backend or database migration is required for this phase.

# GoVia Mobile v0.1.16 – Fullscreen & Background Navigation

## Navigation cockpit
- Active navigation now uses the map as the full-screen surface instead of placing the map inside a normal page column.
- Maneuver guidance, navigation state, ETA/distance/speed and navigation actions are overlays on top of the map.
- Recenter control is lifted above the bottom navigation controls.

## Android background navigation
- The active Geolocator position stream now uses Android `ForegroundNotificationConfig`.
- A persistent `GoVia navigerer` notification keeps the foreground location service active when the app is backgrounded or the screen is locked.
- Navigation GPS processing, maneuver advancement, TTS announcements and rerouting continue while the Flutter navigation session remains active.
- Stopping or completing navigation cancels the position stream and therefore stops the foreground navigation service.
- Force-stopping the app is intentionally not treated as background navigation.

## Arrival & completion
- Arrival is not accepted from one noisy GPS fix.
- GoVia requires three credible arrival fixes: within 25 m, or within 55 m while moving at no more than 5 m/s.
- At arrival the navigation UI changes from `Stopp navigasjon` to `Fullfør tur` for the final stage, or `Fullfør etappe` for intermediate stages.
- TTS announces `Du er fremme.` once.
- Completing the final stage marks the trip completed in the mobile state/history and persists the completion marker locally until the canonical mobile trip snapshot contract is implemented.

## Platform
- Mobile-only release.
- No Raspberry Pi/API changes.
- No Supabase migration.

## v0.1.17 — Profile & Trip History Foundation
- Profile is now editable: display name, location, bio and profile image.
- Added account-backed transport, units, voice, location-sharing and community/privacy preferences.
- Profile now links to real trip history, saved routes, notifications and offline maps.
- Cloud trip hydration now loads authoritative stages so history distance/time are based on real trip data.
- Trip dates/status are parsed from cloud values instead of being replaced with the current time.
- Completing the final stage creates a durable local history snapshot and queues cloud status `Fullført` until acknowledged.
- Completed/archived trips can no longer become the fallback active trip.
- History is split into Planlagt / Pågående / Fullført / Arkivert with real counts and no production dummy content.
