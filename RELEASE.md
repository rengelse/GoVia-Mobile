# GoVia Mobile v0.1.12 – Voice Turn-by-Turn Navigation

## Added
- Normalized navigation maneuver model.
- Route and roundtrip candidates preserve maneuver data from GoVia API.
- GPS-driven next-maneuver progression.
- Norwegian text-to-speech navigation with 650 m / 220 m / 55 m announcement windows.
- Mute/unmute control and pause/resume navigation.
- Stored/community routes without maneuvers are enriched through `/api/v1/map/guidance` when navigation opens.
- Remaining distance/time and maneuver progress are based on the active official route.

## Guidance quality
- OSRM modes use provider-native route steps.
- TomTom Orbis REST routes currently use conservative geometry-derived maneuver events until a native TomTom Navigation SDK integration is introduced. The UI labels this as basis guidance instead of presenting it as provider-native guidance.

## Deploy
- Mobile update required.
- RPi/API v0.86.181 required for guidance enrichment and normalized maneuver responses.
- No Supabase migration.
