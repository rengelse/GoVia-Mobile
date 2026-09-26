# GoVia Mobile v1

Flutter-klient basert på låst GoVia Mobile v1-spesifikasjon og Desktop/backend v0.86.178.

## Scope

22 mobilskjermer er implementert i kodebasen:

1. Velkomst/Login
2. Hjem
3. Mine turer
4. Turdetaljer
5. Etappeliste
6. Etappedetalj
7. Ruteoversikt
8. Aktiv navigasjon
9. Gruppe live
10. Invitasjon/QR
11. Ny tur
12. Planlegg tur
13. Rundtur-generator
14. Ta opp tur
15. Vær
16. Varsler
17. POI/Stopp
18. Chat/Meldinger
19. Deltakere
20. Profil/Innstillinger
21. Offline nedlasting
22. Historikk

Økonomi og utgift er bevisst **ikke** del av mobilappen.

## Hva som er koblet mot dagens GoVia

- Supabase Auth via `supabase_flutter`
- GoVia API bearer auth
- `/api/v1/domain/:repository/:method`
- `/api/v1/map/geocode`
- `/api/v1/map/route` inkludert eksisterende rutealternativer
- struktur for weather/POI/chat/trips
- Android GitHub Releases updater med APK-download og valgfri SHA-256-verifikasjon
- QR-skanner
- GPS-opptak i klient

## Backend-kontrakter som fortsatt må legges til i GoVia-plattformen

Appen skjuler ikke disse som om de allerede virker:

- sikker Desktop → Mobile single-use handoff
- roundtrip-generator basert på ønsket distanse/tid
- normaliserte turn-by-turn maneuvers
- varig `recorded_rides` batch-opplasting
- dedikert mobile live-GPS-kontrakt
- offline MapLibre vektorkartpakker
- MC-ruteprofiler utover dagens serverkontrakt (`fast`)

Se `docs/BACKEND-GAPS.md`.

## Kjøring på Windows / Android

Krever Flutter stable. Første gang du pakker ut kildekoden kan du generere standard Android wrapper/runner-filer med:

```powershell
.\tool\bootstrap_android.ps1
```

Dette bevarer GoVia-manifest og Android-konfigurasjon. Deretter bruker du produksjonsverdier via `--dart-define`:

```powershell
flutter pub get
flutter run `
  --dart-define=SUPABASE_URL=https://<project>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<anon-key> `
  --dart-define=GOVIA_API_BASE_URL=https://govia.no `
  --dart-define=GOVIA_GITHUB_OWNER=rengelse `
  --dart-define=GOVIA_MOBILE_GITHUB_REPO=GoVia-Mobile
```

Eksplisitt lokal utviklingsseed kan slås på separat:

```powershell
flutter run --dart-define=GOVIA_DEV_SEED=true
```

`GOVIA_DEV_SEED` er `false` som standard og skal ikke brukes i produksjonsrelease.

## Release APK / GitHub updater

Bygg:

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<project>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<anon-key> `
  --dart-define=GOVIA_API_BASE_URL=https://govia.no
```

Publiser GitHub Release med tag f.eks. `v1.0.1` og asset:

```text
GoVia-Mobile-v1.0.1.apk
GoVia-Mobile-v1.0.1.apk.sha256   (anbefalt)
```

Updateren installerer aldri noe automatisk. Brukeren initierer nedlasting/installasjon, og Android viser sin egen installasjonsdialog.

## iOS

Dart/Flutter-koden er delt. Native Xcode runner må genereres på macOS:

```bash
./tool/bootstrap_ios.sh
```

iOS kan ikke selvinstallere IPA fra GitHub. Bruk App Store/TestFlight.

## Kart

Mobilklienten er låst til `maplibre_gl 0.27.1` med MapLibre Native på Android/iOS og OpenFreeMap Liberty (`https://tiles.openfreemap.org/styles/liberty`). `RouteMapCard` tegner offisiell rutegeometri og deltakere direkte på kartet. Offline-siden bruker MapLibre offline regions, slik at kartområdet rundt den offisielle ruta kan lastes ned på enheten.

`maplibre_gl 0.27.1` krever Flutter 3.29+ / Dart 3.7+ og **JDK 21** for Android-build. Prosjektets GitHub Actions og lokal Android-maskin må derfor bruke JDK 21.

Dette er viktig: produksjonsrouting kommer fra GoVia API. Klienten skal ikke inneholde TomTom-hemmeligheter.


## Runtime configuration (v0.1.2+)

Normal development launch no longer requires Supabase dart-defines:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

The production Project URL and public/publishable Supabase client key are built in to match GoVia Desktop. They are public client configuration, not privileged service-role secrets. Deployments can still override them with `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`.

`Planlegg tur` uses authenticated GoVia API geocoding. Type at least two characters, select a returned place, and the resolved coordinate is shown on the map before routing.
