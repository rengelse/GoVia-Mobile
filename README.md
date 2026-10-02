# GoVia Mobile v0.1.133+134 – Acceptance Gate Diagnostics Hardening
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