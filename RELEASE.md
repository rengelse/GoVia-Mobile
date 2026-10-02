# GoVia Mobile v0.1.135+136 – Map Home Theme & Layout Refinement

## v0.1.135 – Map Home Theme & Layout Refinement

### Theme-aware Map Home
- The map home now follows the persisted app theme instead of forcing dark mode.
- `system`, `light` and `dark` are supported through Profile → App → App-tema.
- Dark mode uses OpenFreeMap `dark`; light mode uses `liberty`.
- Search, chips, weather/profile surfaces, map controls and bottom navigation derive their colors from the active brightness.

### Destination search
- The main search field is now a real destination/place/address search, not an Oppdag shortcut.
- Search uses the same Photon provider family already used by trip planning, with Norwegian-first language negotiation.
- Selecting a result opens Planlegg tur and preselects that destination.
- The filter button still opens route discovery, keeping targeted search and inspiration separate.

### Layout refinement
- Search field and discovery chips are more compact.
- Empty published-route state no longer renders a large promo-like placeholder card.
- Planlegg tur is raised above the bottom navigation.
- Bottom navigation is slightly shorter while keeping Turer / Kart / Varsler / Profil and the unread badge.
- No navigation/Ferrostar, notification, weather backend or route-provider contracts are changed.

## v0.1.134 – Notification Badge Test Alignment

- Updates `notification_center_test.dart` to assert the unread badge in `lib/app/shell_screen.dart`, which became authoritative in v0.1.132.
- Verifies the unread count is passed to the `Varsler` destination and that `99+` capping remains intact.
- No production code changes.

## v0.1.133 – Acceptance Gate Diagnostics Hardening

- Keeps the v0.1.132 map-home redesign and trip-discovery carousel unchanged.
- Reworks `tool/navigation_acceptance_gate.py` so every subprocess is logged in execution order.
- Prints the exact command, merged stdout/stderr and explicit PASS/FAIL exit code for static preflight, runtime verifier, Flutter analyze, Flutter tests and native JVM tests.
- Prevents buffered Python labels from appearing after Gradle output and hiding which earlier gate actually failed.
- No production navigation, UI, notification, weather or Ferrostar runtime behavior is changed in this release.

## v0.1.132 – Map Home Redesign & Trip Discovery Carousel

### Map-first home
- The main shell now opens directly on Kart.
- The approved dark premium map composition is implemented with GoVia branding, weather/profile header, search, quick discovery chips, map controls and the floating Planlegg tur CTA.
- Active trip route geometry is highlighted on the home map when available.

### Trip discovery carousel
- The old promotional/banner slot is removed.
- The same space now hosts a horizontally scrollable carousel of actual `PublishedRoute` records from the existing GoVia community route source.
- Routes with photos are prioritized, followed by rating/count.
- Cards show route image, title, category/transport, distance and duration and open the existing published-route detail flow.
- No hardcoded Lofoten/Atlanterhavsveien/Trollstigen demo data is introduced; those names appear only when corresponding published routes actually exist.

### Shell navigation
- Bottom navigation is reduced to the approved four destinations: Turer, Kart, Varsler and Profil.
- Varsler keeps the unread badge and is now a first-class shell destination.
- New trip and Discover remain available through the map home CTA/search/chips and existing routes.

### Scope
- No Ferrostar/navigation-runtime changes.
- No database migration.
- No API/server contract change.


## v0.1.131
- Connects Mobile Varsler to existing shared `trip_notifications` persistence/realtime.
- Enforces self-action suppression using `actor_id == current user`.
- Retains system-generated events and notifications from other trip members.
- Synchronizes cloud read state and keeps archived cloud notifications from reappearing locally.
- Makes Vær operational for selected/created trips through `/api/v1/weather/route`.
- Uses route geometry and trip date, with explicit nine-day forecast-window handling.
- Adds deduplicated material weather alerts to the same notification inbox.
- No direct MET Norway calls and no parallel notification store.
- Background OS push is not claimed by this release; realtime operates while the authenticated app session is connected.


## v0.1.130
- Removes the four hard-coded notification demo cards.
- Adds persistent typed notification storage and read/unread state.
- Adds Home unread badge, Today/Earlier grouping, mark-all-read, archive/clear and empty state.
- Adds action targets for trip, stage, group, weather, offline and chat destinations.
- Connects existing application events to the inbox: Desktop handoff, route update, stage/trip completion, ride recording import and offline package result.
- Adds notification-center tests and release-preflight contracts.

## v0.1.129

- Removes the unused simulator helper that caused `flutter analyze` to fail.
- No production runtime behavior changes from v0.1.128.

## v0.1.128

- Localizes current/next navigation-card instructions from semantic maneuver data on phone.
- Localizes Android Auto Step text through the same navigation-language policy.
- Adds Android TTS service discovery query for reliable speech output.
- Makes simulator scenarios deterministic when the live routing API is unavailable.
- Densifies built-in simulator geometry and assigns explicit Ferrostar shape indexes.
- Anchors live simulator-only provider maneuvers to simulator geometry before strict runtime conversion.