# GoVia Mobile v0.1.27 – Android Auto Foundation

- GoVia er nå deklarert som ekte Android Auto navigasjonsapp via AndroidX Car App Library 1.7.0, `CarAppService`, template discovery og navigation surface permission.
- Android Auto startsiden har kontekstuell `Fortsett` når en tur er aktiv, samt valgene `Turer` og `Ta opp`. Disse valgene ligger ikke fast over aktiv navigasjon.
- `Turer` viser reelle planlagte/aktive turer som Mobile har synkronisert til en varig Android Auto-cache, med turdetalj før `Start tur`.
- Aktiv Android Auto-navigasjon bruker GoVia-rutegeometri, GPS-posisjon, hostens `NavigationTemplate`, neste manøver og samme 650/220/55 m stemmevarsling.
- Kartflaten har GoVias egen mørke/oransje route-renderer. Dette er en native Android Auto surface og ikke speiling av Flutter-skjermen.
- POI-awareness er koblet inn i car navigation: POI som finnes i Mobile-state kan varsles visuelt på kartflaten og med tale når brukeren nærmer seg. Ingen dummy-POI legges til i produksjon.
- `Ta opp` starter native foreground GPS-opptak fra Android Auto. Når opptaket stoppes lagres sporet lokalt og importeres tilbake til GoVia Mobile som en fullført lokal tur ved neste appstart.
- Android Auto og telefonappen deler ikke JWT eller hemmeligheter; car host leser kun en eksplisitt, lokal read-cache med tur/rute/maneuverdata.
- Ingen RPi/API- eller Supabase-migrasjon kreves for denne fasen. Varig cloudmodell for `recorded_rides` er fortsatt separat backend-arbeid.

# GoVia Mobile v0.1.26 – Navigation Runtime & Voice Fix

- Start navigasjon aktiverer nå den konkrete turen som `Aktiv` og lagrer aktiv tur før navigasjonsskjermen åpnes.
- GPS live-stream startes før one-shot GPS-prime, slik at en treg `getCurrentPosition()` ikke kan holde kontinuerlig sporing tilbake i opptil 15 sekunder.
- Android ber om varslingstillatelse uten å blokkere GPS og har eksplisitt WAKE_LOCK-tillatelse for foreground navigation.
- Stemmeveiledning følger profilinnstillingen `voice_enabled` og gir en hørbar «Navigasjon startet.»-bekreftelse når TTS er klar.
- Slås stemme på igjen under kjøring, gis ny oppstartsbekreftelse og ordinære manøvervarsler fortsetter ved 650/220/55 meter.
- Pending turstatus-sync håndterer nå både `Aktiv` og `Fullført` uten å sette en falsk sluttdato ved oppstart.
- Ingen RPi/API- eller Supabase-migrasjon kreves for denne mobiloppdateringen.

# GoVia Mobile v0.1.25 – Navigation Continuity Test Hardening

- Retter foreldet regresjonstest for GPS-prime/Picture-in-Picture.
- Verifiserer eksplisitt one-shot GPS-fix med 15 s timeout.
- Verifiserer kontinuerlig GPS-stream separat.
- Verifiserer Android MethodChannel, PiP entry og manifeststøtte.
- Ingen runtime-endring.

# GoVia Mobile v0.1.24 – Discover Carousel, Trip Delete & Navigation Continuity

- Oppdag: Nær meg og Globalt er tydelige horisontale carouseller uten 10-rutersgrense.
- Mine turer: eier kan slette egen tur med bekreftelse via eksisterende sikre trip.delete-kontrakt.
- Navigasjon: GPS primes med last-known + aktiv current-position før kontinuerlig stream, så cockpit ikke blir stående unødvendig på Venter på GPS.
- Android: aktiv navigasjon går til Picture-in-Picture når brukeren går til Home/gesture ut av appen; foreground location/TTS fortsetter mens navigasjonssesjonen lever.
- Android: vedvarende navigasjonsvarsel leder brukeren tilbake til GoVia når appen ikke er synlig.
- Ingen RPi/API- eller Supabase-endring.

# GoVia Mobile v0.1.23 – Secure Desktop Trip Handoff

- Desktop QR handoff now redeems a real, authenticated, single-use trip token.
- Imported snapshots are bound to one exact `trip_id`; stages from another trip are rejected.
- Successful handoff merges the exact trip into Mobile, selects it as active, and refreshes trip-scoped chat state.
- Removed the old placeholder that claimed the consume backend was missing.

# GoVia Mobile v0.1.22 – Information Architecture & UI Hardening

- Main navigation is now Hjem / Turer / Ny tur / Oppdag / Profil; Gruppe is contextual to an active trip.
- Profile no longer duplicates trip status cards. It is focused on account, navigation, privacy, content and app settings.
- Turer is the single source for Planlagt / Aktiv / Fullført / Arkiv with status filters and counts.
- Hjem is simplified around the active trip, or three clear entry actions when no trip is active.
- Oppdag no longer duplicates Mine turer; it focuses on nearby/global community routes, saved routes and own publications.
- No backend, Raspberry Pi or Supabase changes are required.

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
