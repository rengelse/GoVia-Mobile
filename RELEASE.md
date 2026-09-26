# GoVia Mobile v0.1.0 – Full v1 Client Baseline

Første komplette Flutter-klientbaseline basert på låst GoVia Mobile v1-design og scope.

## Inkludert
- 22 låste skjermer
- mørkt GoVia designsystem
- Hjem · Turer · + Ny tur · Gruppe · Profil
- Supabase Auth adapter
- GoVia API client
- ekte geocode + road route-kall mot eksisterende GoVia API
- visning av flere route candidates
- ferry-safe mobilmodell
- QR scanner + reserved universal/deep link
- GPS ride recording client
- group/live UI boundary
- chat/participants/weather/POI/offline/history
- Android GitHub Release updater
- APK SHA-256 verification
- GitHub Actions release pipeline
- Android signing hook
- Android location/camera/install permissions
- explicit DEV seed, disabled by default

## Bevisst ikke simulert
Følgende mangler backendkontrakt i GoVia v0.86.178 og er derfor sperret/dokumentert i stedet for fake-implementert:
- Desktop → Mobile handoff consume
- roundtrip-generator
- normalized turn-by-turn maneuvers
- recorded ride cloud persistence
- live GPS publish contract
- offline vector map packs
- advanced MC route profiles

Se `docs/BACKEND-GAPS.md`.
