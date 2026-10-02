# GoVia Mobile v0.1.131+132 – Trip Event Notifications & Weather Foundation

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
