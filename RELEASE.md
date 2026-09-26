# GoVia Mobile v0.1.2 – Auth, Brand & Place Search Hardening

## Fixed
- Mobile now uses the same GoVia horizontal brand logo and launcher mark as Desktop.
- Production public Supabase URL + publishable key are available by default; ordinary `flutter run` no longer requires manual auth dart-defines.
- `SUPABASE_PUBLISHABLE_KEY` remains overrideable with `--dart-define`; legacy `SUPABASE_ANON_KEY` is accepted as fallback.
- Planlegg tur now performs live GoVia `/api/v1/map/geocode` search for start, optional via stop and destination.
- Search results show place labels and coordinates; a place must be selected before route calculation.
- Selected places are rendered as map markers immediately.
- Route calculation uses the selected coordinates instead of silently geocoding arbitrary free text at submit time.
- Returned route geometry replaces the location-only preview and preserves alternative route selection.

## Backend / deploy
- Mobile-only release.
- No GoVia RPi/API code change.
- No Supabase migration.
- Existing authenticated `/api/v1/map/geocode` and `/api/v1/map/route` endpoints are reused.

## Version
- `0.1.2+3`
