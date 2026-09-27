# GoVia Mobile v0.1.16

Flutter mobile client for GoVia. This baseline includes transport-aware route planning, Discover/community routes and photos, trip chat actions, roundtrip routing, GPS/TTS turn-by-turn guidance, navigation cockpit/map matching/rerouting, Android background navigation, full-screen navigation and arrival/completion flow.

See `RELEASE.md` for the current release changes and `docs/` for product/backend status.

### v0.1.17 profile/history hardening
GoVia Mobile now uses the shared account profile for editable personal data and navigation/community preferences. Trip history is hydrated from authoritative cloud trips + stages, while offline completion is retained locally until cloud status synchronization succeeds.
