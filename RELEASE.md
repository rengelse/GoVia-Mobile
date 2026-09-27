# GoVia Mobile v0.1.11 – Analyzer & Location API Hardening

## Fixed
- Removed unnecessary `dart:typed_data` import from app state.
- Migrated all current-position calls from deprecated `desiredAccuracy` to `LocationSettings`.
- Added a mounted guard in roundtrip generation before using `BuildContext` after an async location lookup.

## Scope
- Mobile-only maintenance release.
- No runtime behavior change intended.
- No RPi/API or Supabase migration required.
