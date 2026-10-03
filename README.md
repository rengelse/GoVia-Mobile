# GoVia Mobile v0.1.146+147 – Functional Trip Maps

## v0.1.146 – Functional Trip Maps

- Makes Planlegg tur use a compact map before any start/via/destination has been selected, then expands to the existing full route preview when trip data exists.
- Moves the round-trip start selector ahead of the map and hides the map until a start point exists; a selected origin gets a compact map and generated alternatives retain the full preview.
- Removes the passive pre-recording map from Ta opp tur and replaces it with a clear ready state.
- Adds a live GPS track preview while phone recording is active. The preview is sampled for UI efficiency and is intentionally separate from the authoritative Android foreground-service recording.
- Keeps background recording, saved ride data, routing, Ferrostar/Navigation Core, Android Auto and server/API contracts unchanged.

Validation: static preflight, verify_mobile and CI-contract checks run locally where supported. Flutter/JVM/emulator/GitHub CI require external verification.


# GoVia Mobile v0.1.145+146 – Trip Hub & Three-Tab Shell

## v0.1.145 – Trip Hub & Three-Tab Shell

- Removes the decorative map from the trip entry screen and turns the screen into a focused Turer hub.
- Adds Mine turer to the hub alongside Desktop handoff, planning, round-trip generation and ride recording.
- Reduces bottom navigation to Kart / Varsler / Profil and keeps Kart as the default shell destination.
- Remaps shell shortcuts so profile, notifications and update navigation still target the correct destination.
- Changes the Map Home primary CTA to Turer because it opens the broader trip hub.
- Preserves navigation/Ferrostar, Android Auto, offline maps, themes, notifications and API/server contracts.

Validation: static preflight, verify_mobile and CI-contract checks. Flutter/JVM/emulator/GitHub CI require external verification.


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

## v0.1.134

- Aligns the notification badge source contract test with the v0.1.132 shell navigation redesign.
- Verifies unread count is wired to the Varsler bottom-navigation destination and keeps the 99+ cap.
- No production runtime or UI behavior changes.

## v0.1.133
- Retains the v0.1.132 map-first home UI unchanged.
- Makes the navigation acceptance gate print each command, full merged output and explicit exit code in deterministic order.
- This release exists to expose the exact Flutter gate failure instead of ending with an ambiguous aggregate exit code.

## v0.1.132
- Replaces the old dashboard-style home with a map-first GoVia home inspired by the approved UI baseline.
- Locks the shell navigation to Turer / Kart / Varsler / Profil and opens on Kart.
- Uses OpenFreeMap/MapLibre as a full-screen map surface with dark/light map toggle and active-trip route overlay.
- Replaces the promotional banner with a horizontal, image-led carousel backed by existing published GoVia routes.
- Discovery cards use real published-route photos when available and show title, category/transport, distance and duration.
- Adds compact weather/profile header, search entry, discovery shortcuts and the floating Planlegg tur action.
- Keeps existing trip planning, Discover, notifications, weather and profile flows as the source of truth behind the new home UI.


## v0.1.131

This release connects the mobile notification center to GoVia's existing shared trip event stream and makes route weather operational for planned trips.

- Reads recipient-targeted events from the existing Supabase `trip_notifications` table and listens for INSERT/UPDATE events while the app session is active.
- Suppresses self-actions when `actor_id` matches the signed-in mobile user, while system-generated events without an actor remain eligible.
- Preserves local read/archive state and maps cloud targets to trip, stage, group, chat and weather destinations.
- Reuses the existing authenticated `POST /api/v1/weather/route` API with official route geometry, trip date and the server's nine-day forecast contract.
- Automatically refreshes trip weather when a trip becomes active/selected or is created locally.
- Adds material weather alerts for strong wind, significant precipitation, winter conditions and thunder without creating notifications for normal forecast refreshes.
- Keeps weather provider access behind GoVia API/capability enforcement; Mobile never calls MET Norway directly.
- This release provides durable inbox sync plus realtime delivery while the app is connected. OS-level background push (FCM/APNs) remains a separate future transport layer.


## v0.1.130

This release replaces the hard-coded notification demo with a persistent GoVia notification inbox.

- Adds a typed `GoViaNotification` model with category, priority, read state, metadata and action target.
- Adds a local `NotificationRepository` backed by the existing `LocalStore`.
- Adds unread count, mark-one-read, mark-all-read, archive and clear operations to `AppState`.
- Rebuilds the notification screen around live application state with Today/Earlier grouping, unread markers, empty state and deep links.
- Adds unread badges on Home and unread status in Profile.
- Emits real local notifications for Desktop handoff, route changes, stage/trip completion, Android Auto ride imports and offline download results.
- Keeps remote push/backend delivery out of this foundation so it can later feed the same repository instead of creating a parallel inbox.

## v0.1.129

This maintenance release removes the unused `_pointAtDistance` helper left behind by the v0.1.128 simulator refactor. No production navigation, voice, localization, completion-flow, Ferrostar runtime, or simulator behavior is changed.

## v0.1.128

This release fixes three runtime regressions found after v0.1.127:

- Navigation cards now render semantic instructions in the selected navigation language instead of raw provider instruction text. The same policy is used by phone and Android Auto.
- Android declares the TTS service query required for reliable speech-engine discovery on current Android versions. Navigation TTS continues to use semantic GoVia localization.
- The navigation simulator no longer depends on a successful live routing request. Built-in scenarios are densified and carry explicit Ferrostar shape indexes; live provider maneuvers are normalized to simulator geometry before entering the strict production adapter.

The Ferrostar production runtime and strict production maneuver anchoring remain unchanged.
