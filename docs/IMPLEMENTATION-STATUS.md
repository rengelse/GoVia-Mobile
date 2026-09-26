# GoVia Mobile v0.1.0 – Implementation status

## Implementert i klienten

- 22 låste v1-skjermer. Økonomi/utgift er eksplisitt utelatt.
- GoVia mørkt design med orange/cyan aksenter og map-first layout.
- Hovednavigasjon: Hjem · Turer · + Ny tur · Gruppe · Profil.
- Supabase Auth-adapter og GoVia bearer API-klient.
- Eksisterende GoVia `/api/v1/map/geocode` og `/api/v1/map/route` brukes av Planlegg tur.
- Route candidates/preview/offisiell rute er separate klientmodeller.
- Ferge behandles som egen etappetype og skal aldri tegnes som falsk bilgeometri.
- MapLibre Native (`maplibre_gl 0.27.1`) + OpenFreeMap Liberty.
- Offline MapLibre-region basert på offisiell route geometry.
- GPS-opptak på enheten med eksplisitt location permission.
- QR-scanner og `https://govia.no/m/<token>` deep-link-reservasjon.
- Android GitHub updater med release check, APK-download, progress, SHA-256 og install-intent.
- GitHub Actions for analyze/test/signert APK/release assets.
- Dev seed finnes kun bak `GOVIA_DEV_SEED=true`; produksjonsmodus genererer ikke falske cloud-data.

## Krever nye GoVia-plattformkontrakter før funksjonen kan være produksjonsklar

- Desktop → Mobile single-use handoff create/consume.
- Canonical mobile trip snapshot/read model.
- Normaliserte turn-by-turn maneuvers fra server.
- Roundtrip-generator.
- Balansert/svingete/maks-svingete MC-profiler.
- Varig live GPS-delingskontrakt.
- Varig recorded-rides/batched track-kontrakt.
- Push notification backend/device-token lifecycle.

Disse funksjonene er med i UI/arkitekturen, men klienten later ikke som serverkontraktene finnes.

## Build-verifikasjon

Kildepakken er statisk kontrollert av `tool/verify_mobile.py`. Denne arbeidscontaineren har ikke Flutter/Dart SDK, så `flutter analyze`, `flutter test` og APK-kompilering må kjøres på Flutter-maskin eller i GitHub Actions. Android-build for MapLibre skal bruke JDK 21.
