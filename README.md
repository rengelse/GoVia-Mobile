# GoVia Mobile v0.1.130+131 – Notification Center Foundation

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
