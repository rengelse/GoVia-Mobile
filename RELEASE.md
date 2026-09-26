# GoVia Mobile v0.1.7 – Route Candidate & Profile Hardening

## Fixed
- Route maps now remount/redraw when preview geometry changes, so selecting another route candidate no longer leaves stale/blank map annotations.
- Choosing a route preserves the complete candidate set and marks only the selected route official.
- Trip detail now renders the official route geometry instead of an empty map.
- Route profiles are no longer dead UI: Raskest, Balansert, Svingete and Maks svingete rank the real route candidates using time, distance and measured geometry curvature.

## Scope
- Mobile-only release.
- No RPi/API changes.
- No Supabase migration.
