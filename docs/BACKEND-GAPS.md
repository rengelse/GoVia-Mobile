# GoVia Mobile – nødvendige plattformutvidelser

Dette dokumentet skiller eksisterende v0.86.178-kapasitet fra nye kontrakter som Mobile trenger.

## 1. Desktop → Mobile handoff

Ny API-kontrakt:

- `POST /api/v1/mobile/handoff` (Desktop, autentisert)
- oppretter kryptografisk tilfeldig token
- 5–10 min TTL
- single-use
- bundet til `trip_id` og normalt `created_by`
- `POST /api/v1/mobile/handoff/consume` (Mobile, autentisert)
- returnerer canonical mobile trip snapshot

QR inneholder kun `https://govia.no/m/<token>`.

## 2. Mobile trip snapshot

Dedikert read-model anbefales fremfor at mobilen må kjenne alle Desktop repositories.

Minimum:
- trip
- participants (begrenset profil)
- stages sortert på dag + position
- official route geometry
- route revision/version
- POI/stops
- ferry metadata
- offline revision

## 3. NavigationRoute

Fra GoVia Platform v0.86.181 leverer route-kontrakten geometry/distance/duration/alternatives og normaliserte `maneuvers[]`. OSRM-trinn er provider-native; TomTom Orbis REST bruker foreløpig konservative geometry-events og må senere erstattes/forsterkes med native TomTom Navigation SDK for full map matching/guidance.

Kontrakten inneholder:

- geometry
- distanceMeters
- durationSeconds
- `maneuvers[]`
  - coordinate
  - instruction
  - roadName
  - type
  - modifier
  - distanceToNextMeters
- routeVersion

Providerformat (TomTom/OSRM) skal normaliseres server-side.

### Guidance semantics gap

Navigation Experience v1.1 krever at routinglaget bevarer reell manøversementikk. For rundkjøringer og motorveiavkjøringer må `maneuvers[]` levere strukturert `type`, `modifier`, `exit`, `roadName` og `roadRef` når provideren har dette. Mobile-klienten skal ikke gjette rundkjøring eller avkjøring fra fritekst. Manglende `exit`-nummer er tillatt; `type=roundabout` skal fortsatt gi rundkjøringsveiledning og `type=off_ramp|exit` skal fortsatt gi «Ta neste avkjøring».

## 4. Roundtrip

Ny funksjon/API for:
- start
- distance/duration target
- direction preference
- route profile
- avoid settings
- ferry setting
- 1–3 candidates

## 5. Route profiles

Dagens TomTom Orbis-request i v0.86.178 bruker `routeType: fast`.
Mobile UI skal ikke markere Balansert/Svingete/Maks svingete som aktiv før serveren har eksplisitt støtte.

## 6. Live GPS

Presence topic kan gjenbrukes for presence, men live GPS trenger kontrakt for:
- tripId/stageId/userId
- lat/lon
- heading/speed/accuracy
- timestamp
- sharingState
- throttling + stale timeout

Ingen posisjon uten eksplisitt aktiv deling.

## 7. Recorded rides

Ny varig modell:
- `recorded_rides`
- komprimert/batched track
- metadata/statistikk

Ikke én Supabase-rad per GPS-sekund.

## 8. Offline maps

Klienten er nå låst til `maplibre_gl 0.27.1` + OpenFreeMap Liberty-style og bruker MapLibre Native offline regions på Android/iOS. Offlinekart lastes fra den offisielle rutegeometrien med en begrenset buffer og zoom-range.

Gjenstående plattformbehov er ikke valg av kart-SDK, men å levere et stabilt mobile snapshot med route revision/maneuvers slik at klienten kan avgjøre når en tidligere nedlastet offlinepakke er utdatert.

## Community / Discover

GoVia platform v0.86.179 now provides the first live `published_routes` contract, RLS, favorites and photo metadata tables. Mobile v0.1.8 consumes it for Discover, publishing, clone/import and favorites.

Still outstanding:

- binary photo upload/storage workflow and image moderation
- richer transport-aware search/ranking beyond basic transport filtering
- ratings/comments if later approved
- canonical Desktop/Mobile trip snapshot remains a separate platform contract

A published route always includes its transport mode. Motorcycle-specific metrics such as curve score must never be required for car, walking, cycling, train or ferry routes.
