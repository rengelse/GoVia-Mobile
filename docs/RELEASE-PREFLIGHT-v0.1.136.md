Version: v0.1.136+137
GitHub tag: v0.1.136 (prepared, not pushed)
Release title: v0.1.136 – Map Home Controls, Logo & Local Weather
GitHub Desktop Summary: Fix map layers, logo, CTA spacing and map-area weather
GitHub Desktop Description:
Bundle the canonical logo asset and align it at the top-left safe area.
Place the planning CTA 16 dp above the shell bottom inset.
Add persisted Standardkart/Fargekart choices following app theme; retain map camera.
Fetch the map-centre daily forecast through the existing GoVia weather API.
Display daily range and actionable errors; retain trip weather and notification inbox.

Checks passed locally:
- Static release preflight
- verify_mobile
- CI contract verifier
- Dart grammar parse (syntax only)
- Existing v0.86.190 server weather route tested with coincident endpoints and mock provider
- FULL/UPDATE reconstruction, ZIP CRC and release ZIP contract

Not run / not verified:
- Flutter analyze and Flutter tests (no Flutter SDK in workspace)
- Native JVM tests and Android emulator acceptance gate
- GitHub CI and actual production weather request
- Device visual verification

Weather uses /api/v1/weather/route with two identical coordinates and no tripId.
The verified server contract supports this; no RPi update or migration is required.
It remains subject to the account weather.route entitlement and server provider configuration.
The map chip shows today's forecast for the map centre, not a live observation.
Tap the location button without an active route for device position (permission required).
Tap weather for details/errors/retry or the existing trip-weather screen.

UPDATE overlays v0.1.135 at repository root. No deletions.
Standardkart: Liberty (light) / Dark (dark).
Fargekart: Bright (light) / Fiord (dark).
