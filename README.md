# GoVia Mobile v0.1.30

Flutter mobile client for GoVia. This baseline includes transport-aware route planning, Discover/community routes and photos, trip chat actions, roundtrip routing, GPS/TTS turn-by-turn guidance, navigation cockpit/map matching/rerouting, Android background navigation, Android Auto navigation/ride recording, full-screen navigation and arrival/completion flow.

See `RELEASE.md` for the current release changes and `docs/` for product/backend status.

### v0.1.18 profile/history hardening
GoVia Mobile now uses the shared account profile for editable personal data and navigation/community preferences. Trip history is hydrated from authoritative cloud trips + stages, while offline completion is retained locally until cloud status synchronization succeeds.

### v0.1.23 secure Desktop handoff

- Scan a Desktop trip-card QR to redeem one exact authenticated trip snapshot.
- The handoff is short-lived and single-use; stages are rejected if their trip ID does not match the imported trip.

### v0.1.22 information architecture hardening
Profil is focused on account/settings, trip statuses live under Turer, Oppdag is a primary navigation destination, and Hjem is simplified around the active trip.
