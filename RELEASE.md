# GoVia Mobile v0.1.16 – Fullscreen & Background Navigation

## Navigation cockpit
- Active navigation now uses the map as the full-screen surface instead of placing the map inside a normal page column.
- Maneuver guidance, navigation state, ETA/distance/speed and navigation actions are overlays on top of the map.
- Recenter control is lifted above the bottom navigation controls.

## Android background navigation
- The active Geolocator position stream now uses Android `ForegroundNotificationConfig`.
- A persistent `GoVia navigerer` notification keeps the foreground location service active when the app is backgrounded or the screen is locked.
- Navigation GPS processing, maneuver advancement, TTS announcements and rerouting continue while the Flutter navigation session remains active.
- Stopping or completing navigation cancels the position stream and therefore stops the foreground navigation service.
- Force-stopping the app is intentionally not treated as background navigation.

## Arrival & completion
- Arrival is not accepted from one noisy GPS fix.
- GoVia requires three credible arrival fixes: within 25 m, or within 55 m while moving at no more than 5 m/s.
- At arrival the navigation UI changes from `Stopp navigasjon` to `Fullfør tur` for the final stage, or `Fullfør etappe` for intermediate stages.
- TTS announces `Du er fremme.` once.
- Completing the final stage marks the trip completed in the mobile state/history and persists the completion marker locally until the canonical mobile trip snapshot contract is implemented.

## Platform
- Mobile-only release.
- No Raspberry Pi/API changes.
- No Supabase migration.
