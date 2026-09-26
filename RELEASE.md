# GoVia Mobile v0.1.5 – Auth Gate, Shared Accounts & UX Hardening

## Fixed

- Release APK no longer overwrites the built-in production Supabase configuration with empty GitHub secrets.
- Mobile uses the same Supabase project and user accounts as GoVia Desktop (`pzhtlbquwvdrqqxrvhct`).
- Empty `--dart-define` values can no longer erase the production public Supabase URL/publishable key.
- Login is now a real auth gate. Android Back cannot reveal the application shell behind the login screen.
- Protected named routes redirect to login when no authenticated session exists.
- Production History no longer contains hard-coded demo trips; only completed/archived real trips are shown.
- Route profile selection now uses a constrained, styled bottom sheet instead of an overflowing dropdown menu.
- Place search remains authenticated by design; once login is valid, start/via/end geocoding uses the same GoVia API bearer session.

## Backend / deployment

- Mobile-only release.
- No RPi/API code changes.
- No Supabase migration.
- No Desktop change.
