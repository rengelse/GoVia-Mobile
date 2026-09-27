# GoVia Mobile v0.1.14 – Navigation Cockpit, Map Matching & Rerouting

- Adds a dedicated forward-looking NavigationMapCockpit instead of the generic full-route map card.
- Navigation camera follows heading with pitch, dynamic zoom and route look-ahead.
- Adds lightweight route map matching for the live GPS position.
- Detects repeated off-route fixes and requests a new route through the existing GoVia route API.
- Adds an explicit recenter control and off-route/rerouting status.
- Keeps Norwegian TTS and official-route maneuver guidance intact.
- No RPi/API or Supabase migration is required for this mobile release; it reuses /api/v1/map/route.
