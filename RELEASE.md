# GoVia Mobile v0.1.1 – Flutter Compile & Analyzer Hardening

Korrigerer første lokale Flutter-verifikasjon av v0.1.0.

## Fikset
- compile-feil i `ParticipantsScreen` (`Future<void?>` → `Future<void>`)
- bootstrap genererte gammel standard `widget_test.dart` med `MyApp`; GoVia sin widget-test følger nå prosjektet og bevares gjennom bootstrap
- Supabase `anonKey`-deprecated call er erstattet med `publishableKey`
- deprecated `RadioListTile.groupValue/onChanged` er fjernet til fordel for eksplisitt kandidatvalg
- deprecated `DropdownButtonFormField.value` er erstattet med `initialValue`
- ubrukte imports fjernet

## Forventet lokal verifikasjon
```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Denne releasen endrer ikke GoVia Desktop/RPi/Supabase-kontrakter.
