# GoVia Mobile implementation status – v0.1.12

## Production-connected
- Supabase shared authentication with GoVia Desktop
- GoVia geocoding and road/walk/cycle/rail routing
- Route candidates and official-route selection
- Roundtrip generation through `/api/v1/map/roundtrip`
- Current-position start selection
- GPS-driven visual + Norwegian TTS navigation
- Normalized maneuver contract from GoVia API; provider-native OSRM steps and explicit geometry fallback for TomTom Orbis REST routes
- Trip chat send/list/like/edit/delete
- Published routes / Discover / favorites
- Community route photos through private Supabase Storage + signed URLs
- Local route recording foundation, MapLibre, offline map foundation, weather/POI surfaces

## Still pending platform contracts
- Secure Desktop → Mobile QR handoff
- Canonical mobile trip snapshot
- Native TomTom Navigation SDK guidance/map matching for full provider-native MC/car voice navigation
- Permanent live GPS sharing
- Permanent recorded-ride persistence
- Push notification device/backend contract
- Full server-defined offline package manifest
- CarPlay / Android Auto
