# GoVia Mobile v0.1.144+145 – Offline Regions & Settings Organization

## v0.1.144 – Offline Regions & Settings Organization

- Adds searchable continent/country/region selection using bundled Natural Earth bounds and existing real MapLibre download status. Keeps custom-area/trip shortcuts.
- Lowers default detail for large bounds to fit existing tile budgets; regions may include water/neighbors. Dataset subdivisions may differ from current administration. No offline routing/search or polygon-clipped country packages.
- Moves Skjerm og kart under Navigasjon og transport. Groups independent Mobiltema and Bilskjermtema under Utseende; saved keys/defaults unchanged.
- Removes only Map Home logo backing in light mode; logo/text/colors unchanged.
- Preserves v143 fixes, navigation/Ferrostar, Android Auto runtime and badge.

Validation: static checks, grammar and ZIP verified. Flutter/tests/JVM/emulator/GitHub CI require external verification.


## v0.1.143 – Screen Settings Test Interaction Fix

- Fixes both settings widget tests to scroll through lazy ListView children, settle layout and assert hit-test visibility before tapping.
- Preserves real UI interactions and all persistence/independence assertions; no production changes.
- Uses the expanded Flutter test reporter in the acceptance gate so failures retain exception details and stack traces alongside COMMAND/RESULT diagnostics.
- Based on v0.1.142. Reported CI baseline: Flutter analyze PASS, 123 tests PASS and two settings widget tests FAIL. The supplied excerpt has no exception details; scrolling is the identified test fragility, and rerun confirmation is required.

Validation: static checks, Dart grammar and release packaging pass. Flutter tests and Android gates cannot be run here without SDKs. CI status remains unverified.


## v0.1.142 – Screen Settings & Visual Speed Warning

- Refines Skjerm og kart into screen, navigation map and speed/warning sections.
- Adds a locally persisted, opt-in visual speed warning. Phone GPS speed and icon use the theme error color with an Over fartsgrensen label when actual unrounded speed exceeds a known native speed limit.
- Requires active navigation, GOOD native GPS quality, valid accurate GPS speed and a sample no older than ten seconds. Unknown limits/speeds never warn. Comparison is unit-independent; km/h and mph display remain supported.
- The warning switch is disabled while own-speed display is hidden; the saved preference is retained. No audible alerts or notification-inbox events.
- Android Auto, Ferrostar guidance/rerouting, map-layer preferences and offline management remain unchanged. Hazard data and custom navigation arrows are not included.
- Adds boundary/invalid-data policy tests and extends persistence/migration tests.

Validation: static checks and Dart grammar pass. Flutter analyze/tests, JVM tests, emulator gates and GitHub CI require SDK/CI verification; not claimed green.


## v0.1.141 – Offline Map Management

- Replaces the trip-only download page with persistent native-region listing, actual completion/progress/resource bytes, area selection, trip-based download, detail levels, pause/continue/stop, deletion and Android update revalidation.
- Fixes the legacy early-success bug: MapLibre returns a region when creation starts; readiness and completion notifications now wait for native status.isComplete, not creation return.
- Downloads both Liberty/light and Dark standard styles sequentially and reuses exact existing definitions. Does not invoke plugin duplicate re-download paths that delete the previous region.
- Pins maplibre_gl to the inspected 0.27.1 API contract.
- Uses native offline storage as the authority across launches. Pauses incomplete regions on launch and active work on background/Wi-Fi loss; continue is explicit. Wi-Fi-only preference is locally persisted.
- Validates bounds, excludes dateline-spanning selections and limits estimated tile count/detail for oversized areas. Does not invent download sizes.
- Lists per-style resource sizes with an explicit shared-cache caveat; does not claim their sum equals disk consumption.
- Adds a narrow Android MapLibre maintenance bridge to resume persisted regions after restart and invalidate resources for server revalidation without deleting the old map.
- Adds tests for actual completion vs creation, interruption preservation, duplicate reuse, Wi-Fi gating, lifecycle pause, native maintenance delegation and bounds/detail budgets.
- Removes MainActivity's legacy forced KEEP_SCREEN_ON flag so v0.1.140's foreground/visible-activity screen-awake policy is authoritative. Picture-in-picture and navigation engine behavior are unchanged.
- Cached standard maps work within downloaded bounds/detail; terrain/satellite, country packages, offline address search and offline route calculation are not included. No server or database migration.
- Update/after-restart maintenance bridge targets Android. iOS basic MapLibre regions remain subject to plugin support; iOS maintenance is not implemented or verified.

Validation: static preflight, verify_mobile, CI contracts and Dart grammar PASS. MapLibre Flutter 0.27.1 source and native 13.6.1 maintenance signatures inspected. Flutter analyze/tests, pub solve, JVM/native build, emulator/flight-mode device checks and GitHub CI remain unverified without SDK/toolchains.


## v0.1.140 – Phone Screen & Map Preferences

- Adds Profil > Innstillinger > Skjerm og kart with locally persisted screen orientation, screen-awake, default navigation map mode, automatic zoom, speed-limit visibility and phone speed visibility.
- Applies system orientation preferences on launch and changes. OS large-screen/multitasking restrictions may override the requested orientation.
- Holds the display awake only for visible active navigation/recording pages while foregrounded. Releases on covered route, stop/arrival, disposal or background; restores on resume/back when appropriate.
- Uses wakelock_plus pinned to 1.3.3, whose declared package_info_plus range supports the existing 8.x dependency. No native navigation modifications.
- Default map mode initializes new phone navigation maps; temporary in-navigation mode cycling remains available. Disabling auto zoom retains camera zoom while position/bearing continue following.
- Screen settings and map mode-control colors follow the existing app theme. The existing phone navigation basemap style is retained. Speed display honors metric/imperial profile units and rejects nonfinite/negative values.
- Visibility choices affect UI only; Ferrostar guidance, speed-limit state, rerouting, Android Auto, map-home layers, weather and notifications retain their existing contracts.
- Adds behavioral tests for preference persistence, malformed values, awake activity policy, route/lifecycle release, zoom and speed formatting, and independent UI choices.
- Offline management and hazard/overspeed alerts are separate future work, not part of this release.

Validation: static preflight, verify_mobile, CI contract verifier and Dart grammar PASS. Flutter analyze/tests, dependency resolution, JVM and Android emulator/GitHub CI are unverified locally because Flutter SDK is unavailable.


## v0.1.139 – Profile Overview & Settings Organization

- Replaces the full settings list on profile entry with avatar, name, email and five compact menu destinations.
- Moves existing controls into account, settings, privacy/sharing, saved/published routes and app/offline pages with native back navigation.
- Shows preferred transport in the settings summary; hides bio, edit controls, developer tools and update details from the overview.
- Retains existing profile API persistence, avatar upload, theme/voice/transport choices, privacy settings, route links, notifications, offline management, updater and sign-out.
- Uses app ColorScheme for profile icons, secondary text and avatar surfaces in light/dark mode.
- Adds overview widget tests for menu actions/back navigation, hidden detail controls, narrow screen and larger text in both themes.
- No backend/migration changes; navigation, map home, notifications and weather are unchanged.

Validation: static preflight, verify_mobile, CI contracts and Dart grammar PASS. Flutter analyze/tests, JVM, emulator and GitHub CI are not verified locally; Flutter SDK is unavailable.


## v0.1.138 – Discovery Filter Compile Fix

- Makes the five Overpass regex filter strings raw Dart strings so literal dollar end anchors do not become interpolation syntax.
- Resolves all nine reported lint messages with widget keys and flow-control braces.
- Preserves regex payloads, category behavior, map settings and all runtime features.
- Addresses all 24 messages in the supplied v0.1.137 Flutter analyze log. Test loading was blocked by the same five compile errors.

Validation: static checks and Dart grammar PASS. Flutter analyze/tests, JVM and GitHub emulator CI remain unverified locally because the SDK is unavailable.


## v0.1.137 – Map Settings & Transport-Aware Discovery

- Replaces the simple map-style panel with persistent Kartinnstillinger: Standard, Terreng and Satellitt, plus independent active-trip, published-route, favorite, completed-trip and place layers.
- Uses OpenFreeMap for the theme-aware standard map, OpenTopoMap raster terrain, and Esri World Imagery raster tiles. Keeps data-source attribution accessible above the bottom navigation. Natural raster imagery/topography is not recolored by app theme; UI overlays follow it.
- Transport chips follow Profile preference and support a temporary MC/car/walking/cycling/train override with a return-to-profile action. Ferry remains an embedded segment, not a primary discovery mode.
- Category chips filter real public PublishedRoute records by transport and explicit category tags. Discovery cards remain independent of map-layer switches.
- Selected place categories request nearby coordinates through existing GoVia POI/around and server Overpass contracts. Food includes restaurant/cafe; accommodation includes hotel/camping.
- MC/bicycle-friendly hotels require explicit source metadata, never generic hotel classification. Sparse specialty metadata can legitimately produce no results.
- Adds coordinate-bearing marker details and destination planning with the selected transport; universal destination search and ordinary planner initialization also honor the selected/profile transport.
- Active routes are orange, public routes blue, favorites green, completed routes purple. Route-start markers open trip details; place markers open destination actions.
- Limits map previews to 50 public routes, 29 completed stage routes and one active route. Samples preview geometry to 250 points without mutating canonical route geometry.
- Serializes overlay refreshes and uses controller epochs to avoid stale annotations after style changes. Preserves camera and cached/debounced weather behavior.
- Splits preferences, category rules, POI repository, overlay renderer, settings UI and home widgets into separate modules.
- Updates the relocated map-style/carousel source contracts; preserves acceptance diagnostics, navigation/Ferrostar, notification badge and trip-weather implementation.

Validation: static preflight, verify_mobile, CI contract and Dart grammar parse PASS. Live sample terrain and satellite tiles returned HTTP 200 and image/png / image/jpeg. Flutter analyze/test, JVM and emulator gates remain unverified because this workspace has no Flutter SDK. GitHub CI is not claimed green.


## v0.1.136 – Map Home Controls, Logo & Local Weather

- Declares assets/brand/ explicitly, fixing the missing logo in the actual Flutter bundle. Constrains its size and aligns the header at the top-left safe area.
- Positions Planlegg tur 16 logical pixels above the shell-provided bottom inset. Avoids counting the bottom navigation inset twice.
- Replaces the information-only map-layer panel with selectable Standardkart and Fargekart. Uses existing OpenFreeMap light/dark variants and persists selection.
- Preserves the camera when changing map style/theme; active route is redrawn without refitting the camera.
- Map Home requests today's daily forecast for the map centre, independent of selected trip/date. Camera tracking and debounced refresh are enabled.
- Reuses the existing authenticated GoVia weather API and TripWeatherParser in AppState. The route contract accepts two coincident endpoints; the first point's daily forecast is used, avoiding doubled route-summary precipitation.
- Displays daily temperature range, wind and precipitation; labels this I dag / Dagsprognose instead of implying a live observation.
- Adds a weather details sheet with actionable entitlement/provider/network errors, retry and link to existing trip weather.
- When no active route is present, recenter requests device location and refreshes weather there. Denied/disabled location is explained; no fabricated location is used.
- Caches nearby forecasts for 30 minutes and rejects stale responses; no separate weather provider, server or database changes.
- Adds behavioral weather tests and an actual Flutter asset-bundle logo test.

Validation: local static preflight, verify_mobile, CI-contract verifier and Dart grammar parse PASS. Flutter SDK is unavailable here; Flutter analyze/test, JVM and emulator gates are NOT verified. Existing GitHub acceptance workflow is unchanged and must pass before publication.


## v0.1.135 – Map Home Theme & Layout Refinement

- Adds persisted App theme (Light/Dark/System) in Profile; existing Android Auto theme remains independent. Existing installs default to Dark.
- Map Home and bottom navigation use Material ColorScheme; home map follows app brightness with OpenFreeMap dark/liberty styles.
- Destination search combines Photon addresses/places (including indexed POI), own trips, published routes and cached trip POI. Selected place coordinates prefill the existing planner destination.
- Extracts the existing Photon request/parser into one shared service, retaining language negotiation and timeout. Rejects stale search responses and invalid coordinates.
- Cached trip POI has no coordinates in the existing model: tapping searches its name for an explicit geocoded selection.
- Compacts search, chips, weather/avatar, carousel and bottom navigation; raises Planlegg tur with safe-area spacing.
- Hides empty discovery carousel. Keeps real PublishedRoute data and photo contrast.
- Preserves notification badge, weather state, navigation/Ferrostar and acceptance diagnostics.

Validation: static preflight and verify_mobile PASS. Acceptance gate reaches BLOCKED because this workspace has no Flutter SDK. Flutter analyze/tests, JVM tests and emulator gate are NOT verified here. GitHub CI must pass before publishing the release.

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