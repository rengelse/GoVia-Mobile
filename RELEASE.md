# v0.1.45 – Android Auto Runtime Crash Fix

- Fixes Android Auto startup/session crash introduced in v0.1.44.
- Home and Trips still use the locked GoVia surface layout.
- Adds the mandatory `ActionStrip` required by `NavigationTemplate.Builder`.
- Home uses `Action.APP_ICON`; Trips uses `Action.BACK`.
- Adds a regression test that rejects bare `NavigationTemplate.Builder().build()` on Home/Trips.
- Keeps the locked navigation cockpit and map rendering unchanged.

## Version
- App: 0.1.45+46
- Tag: v0.1.45
