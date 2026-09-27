# GoVia Mobile v1 – Låst produkt- og teknisk spesifikasjon

**Status:** Design- og scope-baseline  
**Desktop/backend-baseline kontrollert mot:** GoVia v0.86.178  
**Mobilmål:** Companion + selvstendig tur-/navigasjonsapp  
**Foreslått klient:** Flutter (Android + iOS)  
**Visuell baseline:** De allerede godkjente GoVia Mobile-illustrasjonene. De skal ikke redesignes uten eksplisitt beslutning.

---

## 1. Produktdefinisjon

GoVia Mobile er **ikke en mobilkopi av GoVia Desktop**.

Desktop er hovedverktøyet for omfattende planlegging, planleggingsmøte og administrasjon. Mobilappen er bygget rundt:

1. hente en ferdig planlagt tur fra Desktop,
2. planlegge en tur direkte på mobilen,
3. opprette en automatisk rundtur,
4. ta opp en faktisk kjørt tur,
5. navigere etter den offisielle GoVia-ruten,
6. bruke turen offline,
7. følge reisefølget live,
8. håndtere meldinger, deltakere, vær, POI og varsler under reisen.

### Låst prinsipp

> **Plan on Desktop. Ride on Mobile.**

Men Mobile skal samtidig være fullverdig nok til å brukes uten Desktop.

---

## 2. Endelig v1-scope – 22 skjermer

Følgende skjermer beholdes i GoVia Mobile v1:

1. Velkomst / Login
2. Hjem
3. Mine turer
4. Turdetaljer
5. Etappeliste
6. Etappedetalj
7. Ruteoversikt
8. Aktiv navigasjon
9. Gruppe live
10. Invitasjon / QR
11. Ny tur
12. Planlegg tur
13. Rundtur-generator
14. Ta opp tur
15. Vær
16. Varsler
17. POI / Stopp
18. Chat / Meldinger
19. Deltakere
20. Profil / Innstillinger
21. Offline nedlasting
22. Historikk

### Eksplisitt fjernet fra Mobile v1

- Økonomi
- Legg til utgift

Økonomi og oppgjør forblir Desktop-funksjoner.

---

## 3. Låst hovednavigasjon

Den siste godkjente «Ny tur»-illustrasjonen brukes som fasit for hovednavigasjonen:

**Hjem · Turer · + Ny tur · Gruppe · Profil**

### Konsekvens

- **Navigasjon er ikke en permanent hovedfane.**
- Aktiv navigasjon startes kontekstuelt fra Turdetalj, Etappedetalj eller Ruteoversikt.
- Under aktiv navigasjon går appen over i egen kjøremodus med minimalt UI.
- Tilbake fra navigasjon går til aktuell etappe/tur, ikke tilfeldig forrige skjerm.

---

# 4. Skjermspesifikasjon

## 4.1 Velkomst / Login

### Formål
Sikker inngang til GoVia-konto og eksisterende turdata.

### Innhold
- GoVia-logo
- kort produktbudskap
- Logg inn
- Opprett konto
- eventuelt «Fortsett med turinvitasjon» når appen åpnes fra gyldig invite-link

### Ikke tillatt
- demo-bruker som produserer ekte cloud-data
- service-role-nøkkel i appen

### Akseptansekriterier
- eksisterende Supabase-konto kan logge inn
- session gjenopprettes sikkert
- logout fjerner tokens og sensitiv lokal cache

---

## 4.2 Hjem

### Formål
Umiddelbar oversikt over reisen brukeren faktisk skal bruke nå.

### Innhold
- aktiv / neste tur
- dagens etappe
- status: aktiv / planlagt / ferdig
- offline-status
- snarveier til:
  - Åpne etappe
  - Gruppe live
  - Vær
  - Last ned tur
- kommende etapper

### Prioritet
Hjem skal ikke være et sosialt feed. Turen er hovedobjektet.

---

## 4.3 Mine turer

### Faner
- Aktive
- Kommende
- Arkiverte / Historikk

### Hvert turkort viser
- navn
- dato
- start → mål
- deltakere
- antall dager / etapper
- offline-status
- turstatus

### Handlinger
- åpne
- last ned offline
- arkiver der rettigheter tillater det

---

## 4.4 Turdetaljer

### Formål
Mobilens operative turdashboard.

### Innhold
- hero/header fra godkjent design
- turrute i minikart
- fremdrift
- deltakere
- etapper sortert Dag 0, Dag 1, Dag 2 ...
- tydelig transporttype per etappe
- Naviger / Åpne etappe
- værstatus
- offline-status

### Regler
- etapperekkefølge skal bruke faktisk dagnummer, ikke array-posisjon alene
- ferge skal fremstå som ferge, aldri som kunstig bilrute rundt havet

---

## 4.5 Etappeliste

### Sortering
Primært:
1. dagnummer
2. intern posisjon innen samme dag

### Hver rad
- Dag N
- start → mål
- transporttype
- distanse
- estimert varighet
- route/offline-status

### Mobilrettigheter
Vanlig deltaker kan lese. Redigering følger samme autorisasjon som backend/desktop.

---

## 4.6 Etappedetalj

### Innhold
- start
- via/stopp
- mål
- transporttype
- valgt/offisiell rute
- distanse og tid
- POI/stopp
- vær
- offline-status
- Start navigasjon

### Viktig
Mobilen skal bruke **offisiell valgt route geometry** når turen kommer fra Desktop. Den skal ikke stille beregne en «bedre» rute og dermed endre planlagt tur.

---

## 4.7 Ruteoversikt

### Formål
Kontroll før navigasjon.

### Innhold
- full route geometry
- start/mål
- planlagte stopp
- ferry/toll/tunnel/motorway-indikatorer der data finnes
- distanse
- varighet
- værkort
- Start navigasjon
- Last ned offline

### Ruteprinsipp
- Desktop-valgt rute = offisiell rute
- Mobile skal navigere denne geometrien
- ved avvik skal Mobile prioritere å føre bruker tilbake til offisiell rute

---

## 4.8 Aktiv navigasjon

### Må være kjøresikker
Store elementer, lite interaksjon, høy kontrast.

### Minimum
- kart
- egen GPS-posisjon
- offisiell rute
- neste manøver
- avstand til manøver
- veivisningssymbol
- neste veinavn
- ETA
- gjenværende distanse
- mute/unmute stemme
- stopp navigasjon

### Ved ruteavvik
1. oppdag avvik mot planlagt geometry
2. beregn trygg tilkobling tilbake til offisiell rute
3. ikke erstatt hele turen automatisk
4. større omruting krever eksplisitt brukerhandling

### Kritisk ny backendkapabilitet
Dagens v0.86.178 route-normalisering returnerer geometry, distance, duration, alternativer og routeInfo, men ikke et stabilt GoVia turn-by-turn maneuver-format. Mobile krever derfor et nytt serverformat, eksempelvis:

```text
NavigationRoute
- geometry
- distanceMeters
- durationSeconds
- maneuvers[]
  - sequence
  - coordinate
  - instruction
  - roadName
  - type
  - modifier
  - distanceToNextMeters
- routeVersion
```

Provider-rådata skal normaliseres på serveren. Mobilen skal ikke være bundet direkte til TomTom-format.

---

## 4.9 Gruppe live

### Formål
Se reisefølget under aktiv tur.

### Innhold
- kart med deltakere
- avatar / initialer
- navn
- online/offline
- relativ posisjon / avstand der forsvarlig
- gruppestatus
- åpne profilkort
- åpne chat

### Personvern
Live location skal være eksplisitt aktivert under tur. Ingen skjult sporing utenfor aktiv deling.

### Teknisk
Eksisterende GoVia Realtime har allerede autoriserte `rideplan-presence:<trip_id>`-topics. Disse kan gjenbrukes for presence, men varig/løpende GPS trenger en egen, tydelig mobilkontrakt.

### Foreslått live-payload
- userId
- tripId
- stageId
- lat/lon
- heading
- speed (valgfritt)
- accuracy
- timestamp
- sharingState

### Krav
- throttling
- stale timeout
- ingen historisk sporing med mindre bruker eksplisitt tar opp tur

---

## 4.10 Invitasjon / QR

Det skal finnes **to forskjellige QR-konsepter**. De må aldri blandes.

### A. Desktop → Min mobil
Sikker device handoff av en tur.

QR-koden skal **ikke** inneholde:
- Supabase JWT
- service role
- TomTom API key
- hele route geometry
- private turdata i klartekst

QR inneholder kun en kortlivet handoff-token / universal link.

#### Flyt
1. Desktop: «Overfør til mobil»
2. Desktop ber GoVia API opprette transfer-session
3. API lager random single-use token
4. QR viser eksempelvis `https://govia.no/m/<token>`
5. Mobile scanner
6. Mobile må være innlogget
7. server validerer token + bruker + trip
8. token konsumeres
9. Mobile synkroniserer canonical trip snapshot

#### Sikkerhetskrav
- levetid ca. 5–10 min
- single-use
- kan tilbakekalles
- bundet til tripId
- for «min mobil» bør token normalt være bundet til samme bruker som opprettet QR-en

### B. Inviter deltaker
Separat invite-token. Aksept oppretter medlemskap etter eksplisitt bekreftelse.

Eksisterende GoVia har brukerrettede `trip_invitations`; generisk QR-invite krever ny tokenbasert invitasjonskontrakt eller at QR kun peker til en allerede opprettet konkret invitasjon.

---

## 4.11 Ny tur

Denne skjermen er **låst etter godkjent illustrasjon**.

### Øverst
- søk/kart
- severdigheter
- kurver
- ferger

### Desktop-handoff
**Hent fra GoVia Desktop** med QR-scan.

### Tre selvstendige valg
1. **Planlegg tur**
2. **Opprett rundtur**
3. **Ta opp tur**

---

## 4.12 Planlegg tur

### Formål
Opprette full tur direkte på mobilen.

### Minimum v1
- startsted
- ett eller flere stopp
- mål
- rekkefølge kan endres
- transportprofil
- rutepreferanse
- unngå-valg
- beregn rute
- vis inntil 3 kandidater der provider støtter det
- velg én offisiell rute
- lagre som tur/etappe

### Startsted
Skal kunne:
- bruke GPS-posisjon
- søke sted
- velge tidligere/lagrede steder

### Ruteprofil
UI kan støtte konsepter som:
- Raskest
- Balansert
- Svingete
- Maks svingete

**Men:** v0.86.178 TomTom-kallet hardkoder `routeType:'fast'`. Svingete profiler krever først en eksplisitt ny routingkontrakt/backendimplementasjon. UI skal ikke late som profilen virker før serveren støtter den.

---

## 4.13 Rundtur-generator

### Input
- startpunkt
- ønsket distanse **eller** varighet
- retning: fri / nord / sør / øst / vest / tilfeldig
- ruteprofil
- unngå motorvei
- unngå bysentrum
- ferge tillatt/unngå

### Output
- 1–3 rundtur-kandidater
- distanse
- estimert tid
- kart
- velg rute
- lagre / start navigasjon

### Krever ny backend
Dagens `/api/v1/map/route` krever konkrete punkter og lager ikke en roundtrip fra ønsket lengde. GoVia trenger en egen funksjon/API for roundtrip generation.

---

## 4.14 Ta opp tur

### Tilstander
- Klar
- Opptak
- Pauset
- Fullført

### Registrer lokalt
- GPS-route
- tid
- distanse
- hastighet
- høyde dersom tilgjengelig
- pauser

### Etter tur
- lagre historikk
- gi navn
- vis statistikk
- valgfritt konverter til planlagt rute

### Krever nye datamodeller
Dagens GoVia-baseline har presence, men ikke en tydelig varig `recorded_rides`/track-logg for Mobile.

Foreslått modell:

```text
recorded_rides
recorded_ride_points eller komprimert encoded track
```

Rå høyfrekvent GPS bør primært samles lokalt og lastes opp i batch/komprimert form — ikke én Supabase-rad per sekund.

---

## 4.15 Vær

### Gjenbruk
Eksisterende GoVia API har `/api/v1/weather/route` og `/api/v1/weather/radar`.

### Skjerm
- dagens etappe
- timevarsel
- temperatur
- nedbør
- vind
- vær langs ruta
- radar
- eventuelt beste avgangsvindu

### Offline
Siste vær-snapshot kan cache'es med tydelig tidsstempel. Det skal aldri fremstilles som ferskt når telefonen er offline.

---

## 4.16 Varsler

### Typer
- tur endret
- etappe/rute endret
- ny deltaker
- invitasjon
- melding
- værvarsel
- POI/stopp endret
- offlinepakke utløpt/oppdatert

### Navigasjon
Varsel må åpne korrekt trip/stage/context.

Eksisterende `trip_notifications` kan gjenbrukes for turvarsler.

---

## 4.17 POI / Stopp

### Gjenbruk
GoVia API har allerede:
- geocode
- POI around
- POI along route
- POI enrich

### Mobilkategorier
- drivstoff
- mat
- kaffe
- severdigheter
- overnatting
- verksted/service
- fergeterminal

### Handlinger
- se på kart
- legg til som stopp
- naviger dit
- tilbake til offisiell rute

---

## 4.18 Chat / Meldinger

### Gjenbruk
Eksisterende chat conversations/messages og autorisert Realtime-topic kan gjenbrukes.

### Mobil
- trip-chat
- sende tekst
- vise avsender/tid
- unread-state
- åpne fra gruppe/live

### Offline
- siste meldinger kan cache'es
- send mens offline legges i lokal outbox
- sendes ved reconnect

---

## 4.19 Deltakere

### Innhold
- navn
- avatar
- rolle
- online/live status
- kort profil

### Eierfunksjoner
Kun handlinger som backend allerede tillater eller som senere eksplisitt designes. Mobilen skal ikke få skjult adminmakt som ikke finnes i RLS/API.

---

## 4.20 Profil / Innstillinger

### Innhold
- profil
- bilde
- navn
- lokasjon/område hvis ønsket
- kjøretøy
- enheter
- navigasjonsinnstillinger
- stemme
- personvern
- location sharing
- offlinekart
- varsler
- logout

### Sikker lagring
- refresh/access tokens i Keychain/Keystore-kompatibel secure storage
- ingen provider credentials

---

## 4.21 Offline nedlasting

Offline er en **kjernefunksjon**, ikke senere pynt.

### En offline turpakke skal minst inneholde
- trip metadata
- alle nødvendige etapper
- offisiell route geometry
- navigation maneuvers
- planlagte stopp/POI
- nødvendige participant-profiler i begrenset form
- siste relevante weather snapshot
- eventuell ferry metadata
- lokal kartpakke for korridor/område

### Lokal database
Anbefalt Flutter-arkitektur:
- SQLite via Drift eller tilsvarende
- sikre secrets separat i secure storage

### Kart
MapLibre passer godt til GoVia. Men **offlinekart krever en kartkilde/lisens som eksplisitt tillater offline-nedlasting**. Ikke anta at en web tile-endpoint kan massespeiles til mobilen.

### Oppdatering
Offlinepakke har:
- trip revision
- route revision
- downloadedAt
- expires/refresh hint

Appen kan vise «Oppdatering tilgjengelig» uten å ødelegge fungerende offlinepakke.

---

## 4.22 Historikk

### Faner
- Turer
- Opptak

### Viser
- gjennomførte planlagte turer
- egne recorded rides
- distanse
- dato
- varighet
- kartthumbnail

### Skille
Planlagt rute og faktisk kjørt spor er to forskjellige objekter. De må ikke overskrive hverandre.

---

# 5. Desktop → Mobile QR-handoff: endelig design

## Desktop-endring som senere skal implementeres

På relevant tur i Desktop:

**«Overfør til mobil» → Vis QR-kode**

### Desktop skal vise
- turens navn
- QR
- utløpstid
- «Koden kan brukes én gang»
- Avbryt/ny kode

### Serverbehov
Ny liten ressurs, eksempelvis:

```text
mobile_transfer_sessions
- id/token_hash
- trip_id
- created_by
- purpose
- expires_at
- consumed_at
- revoked_at
```

Token lagres helst hashed server-side.

### QR skal ikke være backupformat
Den er en autorisert peker til serverdata. Selve turen kommer via authenticated API/sync.

---

# 6. Datakilder – hva vi allerede har

Kontrollert mot GoVia v0.86.178:

## Kan i stor grad gjenbrukes
- Supabase Auth/profiles
- `trips`
- `trip_members`
- `trip_stages`
- stage `detail_data` med route/stoppstruktur
- `trip_pois`
- `trip_notifications`
- invitations/join request foundation
- chat conversations/messages
- Realtime authorization for trip presence/chat
- map geocode
- POI around/along/enrich
- TomTom/OSRM/Entur routing
- route candidates
- weather route/radar
- RLS for member reads and owner stage mutations

## Må bygges/utvides for Mobile
1. secure Desktop→Mobile transfer-session
2. turn-by-turn maneuver contract
3. reconnect-to-official-route navigation endpoint/logic
4. roundtrip generator
5. recorded rides / GPS track persistence
6. live GPS sharing contract (utover bare generic presence)
7. offline package manifest/revision contract
8. offline-capable map distribution/source
9. eventuell push notification-infrastruktur (APNs/FCM)
10. mobile device/session metadata ved behov

---

# 7. Synkmodell

## Autoritativt prinsipp

**Cloud = autoritativ delt turstate.**  
**Mobil lokal DB = robust offline snapshot + pending local mutations.**

### Lesing
- app starter fra lokal cache umiddelbart
- bakgrunnssynk henter ny cloud revision
- UI skifter ikke til tom state ved midlertidig nettfeil

### Skriving
Kritiske mutasjoner skal være bekreftet før UI sier «lagret» — samme prinsipp som stage-fixen i Desktop.

### Konflikt
- server-authoritative shared data vinner ved konflikt
- lokal pending mutation beholdes og vises som usynket dersom den ikke kan pushes
- ingen silent data loss

### Route revision
En offisiell rute skal ha en stabil revision/version slik at offline Mobile vet om den navigerer en gammel versjon.

---

# 8. Sikkerhetsmodell

## Aldri i APK/IPA
- Supabase service role
- TomTom secret/provider key
- admin credentials
- RPi secrets

## Mobile får
- Supabase/user session
- GoVia API base URL
- public configuration som er trygt å eksponere

## Providerkall
Mobile → GoVia API → TomTom/Entur/weather/provider

Ikke Mobile → hemmelig provider direkte.

## RLS
Mobile skal bruke samme prinsipp som Desktop:
- medlem leser turdata
- tureier muterer offisiell stage-plan der policy sier det
- chat/invites følger egne policy/RPC-er

## QR
- random high entropy
- short-lived
- single-use
- server-side validation
- ingen credentials i koden

## GPS
- eksplisitt brukerhandling
- synlig status når posisjon deles/opptak pågår
- stopp ved avsluttet aktivitet/deling
- privacy by default

---

# 9. Flutter-klientarkitektur

## Foreslått stack
- Flutter stable
- MapLibre Native/Flutter-binding
- Riverpod/BLoC eller tilsvarende konsistent state management
- Dio/http for GoVia API
- Supabase Flutter for auth/realtime der det er riktig
- Drift/SQLite for offline state
- flutter_secure_storage for tokens/secrets
- geolocator/location service for GPS
- background/foreground service på Android for aktiv navigasjon/opptak
- iOS background location kun ved aktiv navigasjon/opptak

## Lagdeling

```text
UI
↓
Application / Use Cases
↓
Repositories
↓
Local DB     GoVia API     Supabase Realtime/Auth
```

Ingen screen skal gjøre rå Supabase-spørringer direkte.

---

# 10. Navigasjonsmotor – ansvar

## Server
- route planning
- candidate generation
- normalized maneuvers
- reroute/rejoin calculations
- provider abstraction

## Mobile
- GPS
- map matching / progress along route
- neste manøver
- stemmeavspilling
- off-route detection
- local navigation state
- offline continuation

## Viktig
Navigation runtime må kunne fortsette uten server så lenge planlagt route + maneuvers + kart er lastet ned.

---

# 11. Tilstandsmaskin for aktiv navigasjon

```text
READY
  ↓ Start
NAVIGATING
  ↔ PAUSED
  ↓ off route
REJOINING
  ↓ back on route
NAVIGATING
  ↓ arrival
ARRIVED
  ↓ finish
COMPLETED
```

Feil i nettverk skal **ikke** flytte appen ut av NAVIGATING hvis offline-data finnes.

---

# 12. Gruppe live – tilstand

```text
OFF
→ SHARING
→ DEGRADED (network poor)
→ SHARING
→ OFF
```

Deltakere med stale GPS skal markeres «Sist sett …», ikke tegnes som sanntid.

---

# 13. Push-varsler

Supabase Realtime er godt for appen når den er aktiv. For varsler når appen ikke kjører trenger Mobile sannsynligvis:

- FCM på Android
- APNs på iOS
- server-side device-token registration
- minimal notification payload
- appen henter autoritativt innhold etter åpning

Ingen sensitiv full turdata i push-payload.

---

# 14. Minimum offline-adferd

Med ferdig nedlastet tur og null internett skal bruker fortsatt kunne:

- åpne tur
- åpne etapper
- se kart for nedlastet område
- se offisiell rute
- starte navigasjon
- få manøverinstruksjoner
- se lokale POI/stopp som var lastet ned
- ta opp GPS-spor lokalt

Skal ikke late som følgende er live:
- vær
- gruppeposisjoner
- chat
- varsler fra andre

---

# 15. Viktige edge cases

## Desktop endrer rute etter at Mobile har lastet ned
- Mobile viser «Ny rute tilgjengelig»
- aktiv navigasjon byttes ikke midt i kjøring uten eksplisitt bekreftelse, med mindre sikkerhetskritisk policy senere bestemmes

## Ferge
- fergeetappe skal ikke konverteres til road-route
- landnavigation kan føre til terminal
- ferry crossing vises separat
- navigation etter ankomst kan fortsette fra neste land-etappe

## Manglende nett ved QR-scan
- QR kan leses, men import må vente til token kan valideres
- token expiry må kommuniseres

## Eier sletter tur
- offlinekopi markeres som ikke lenger synkroniserbar
- beholdes ikke automatisk som aktiv shared trip

## Bruker fjernes fra tur
- cloud access opphører
- sensitiv shared offline-data skal deaktiveres/fjernes etter neste autoritative sync i henhold til produktpolicy

---

# 16. UX-regler

1. Godkjent mørk GoVia-design er baseline.
2. Orange = primær handling/aktiv state.
3. Cyan/blå = kart/navigation/info.
4. Grønn = live/OK/tilkoblet.
5. Rød = stop/farlig/destruktiv handling.
6. Kartet skal ha stor visuell prioritet i navigasjonsrelaterte skjermer.
7. Ingen små kritiske knapper under kjøring.
8. Ingen modal som krever tekstskriving mens navigasjon er aktiv.
9. Aktiv navigasjon skal kunne betjenes med få store handlinger.
10. Appen skal aldri vise falsk route geometry når provider mangler geometry.

---

# 17. Hva Mobile v1 bevisst IKKE skal bli

- full Desktop admin
- Admin Control
- økonomisystem
- avansert planleggingsmøte
- abonnementskatalog-editor
- utstyrsadministrasjon i Desktop-omfang
- systemkonfigurasjon

Mobilen skal være rask, robust og turorientert.

---

# 18. Implementeringsrekkefølge

## Fase M0 – fundament
- Flutter-prosjekt
- theme/design tokens
- auth
- secure storage
- API client
- local DB
- shell navigation

## Fase M1 – cloud trip companion
- Hjem
- Mine turer
- Turdetaljer
- Etapper
- Etappedetalj
- route geometry
- profiles/members

## Fase M2 – QR Desktop handoff
- transfer-session backend
- Desktop QR UI
- Mobile scanner
- import/sync

## Fase M3 – offline
- offline manifest
- route/stage/POI cache
- kartpakker
- update/revision logic

## Fase M4 – navigation
- maneuver backend contract
- active navigation UI
- GPS route progress
- voice
- off-route/rejoin

## Fase M5 – standalone planning
- Ny tur
- Planlegg tur
- route candidates
- choose official route

## Fase M6 – roundtrip + recording
- roundtrip API
- generator UI
- recording engine
- recorded ride history

## Fase M7 – social/live
- Group live GPS
- Chat
- Invitasjon/QR
- Deltakere
- push notifications

## Fase M8 – weather/POI/polish
- vær
- POI
- alerts
- performance
- battery
- Android Auto/CarPlay vurderes etter stabil v1

---

# 19. Akseptansekriterier for Mobile v1

Mobile v1 kan kalles funksjonelt ferdig når alle punkter under er sanne:

### Konto
- [ ] login/logout sikkert
- [ ] session restore

### Desktop handoff
- [ ] Desktop kan generere sikker QR
- [ ] QR inneholder ingen secrets/private trip dump
- [ ] samme autoriserte bruker kan hente tur
- [ ] one-time/expiry håndheves

### Trip
- [ ] cloud-turer vises
- [ ] turdetalj og Dag 0/1/2 sorteres korrekt
- [ ] offisiell route vises identisk med Desktop
- [ ] ferge håndteres uten falsk road geometry

### Standalone
- [ ] Planlegg tur på mobil
- [ ] opptil tre route candidates der provider støtter det
- [ ] eksplisitt valg av offisiell rute
- [ ] rundtur-generator fungerer
- [ ] tur kan tas opp

### Navigation
- [ ] offisiell rute kan navigeres
- [ ] manøvrer og stemme
- [ ] off-route oppdages
- [ ] rejoin uten å kaste planlagt rute
- [ ] fungerer uten nett etter offline download

### Offline
- [ ] trip/stage/route/maneuvers tilgjengelig
- [ ] kart tilgjengelig i nedlastet korridor
- [ ] tydelig stale-state for vær/live/chat

### Gruppe
- [ ] deltakere vises
- [ ] live location er opt-in
- [ ] stale positions identifiseres
- [ ] chat fungerer

### Sikkerhet
- [ ] ingen provider secrets i appen
- [ ] ingen service role
- [ ] RLS/API autorisasjon respekteres
- [ ] secure token storage

### Stabilitet
- [ ] apprestart mister ikke nedlastet tur
- [ ] nettutfall stopper ikke offline navigation
- [ ] failed sync sletter ikke lokal gyldig state
- [ ] route revision-konflikt håndteres eksplisitt

---

# 20. Låste beslutninger per 26.09.2026

1. Eksisterende godkjente illustrasjoner beholdes.
2. Ingen redesignrunde før en konkret skjerm trenger justering.
3. Mobile v1 består av 22 skjermer.
4. Økonomi og Legg til utgift er fjernet.
5. Mobile er både Desktop companion og standalone app.
6. Ny tur har tre valg: Planlegg tur, Opprett rundtur, Ta opp tur.
7. Desktop får senere sikker QR-overføring til Mobile.
8. Hovednavigasjon: Hjem · Turer · + Ny tur · Gruppe · Profil.
9. Desktop-valgt offisiell route skal navigeres som valgt, ikke automatisk erstattes.
10. Offline navigation er et v1-krav.
11. Gruppe live er opt-in og turbundet.
12. Flutter er anbefalt klientplattform.
13. Provider secrets skal kun ligge server-side.
14. Mobile skal gjenbruke eksisterende GoVia API/Supabase-fundament der det passer, men ikke kobles direkte til provider-spesifikke formater.

---

# 21. Konklusjon

GoVia Mobile kan bygges som en naturlig ny klient på dagens GoVia-plattform uten å lage en separat parallell backend. Den nåværende arkitekturen har allerede store deler av fundamentet: Auth, turer, medlemmer, etapper, offisiell route state, kandidat-routing, chat, notifications, POI, weather og autorisert Realtime.

De viktigste nye plattformdelene før Mobile kan bli en ekte Calimoto-lignende navigasjonsapp er:

- sikker QR device handoff,
- normalisert turn-by-turn data,
- roundtrip generation,
- recorded ride persistence,
- live GPS sharing,
- offline package/versioning,
- offline kartdistribusjon,
- push notifications.

Dette dokumentet er dermed **GoVia Mobile v1 scope- og arkitekturbaseline** frem til en eksplisitt senere beslutning endrer den.
