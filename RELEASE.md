# GoVia Mobile v0.1.35 – Android Auto Kotlin Visibility Fix

## v0.1.35

### Build fix
- Fixed Kotlin visibility compilation failure in `GoViaCarMapSurface`.
- `updateNavigationOverlay` and `updateRecordingOverlay` are now `internal`, matching the internal cockpit state types they accept.
- No Android Auto runtime/design rollback; v0.1.34 cockpit and real light/dark themes are retained.


- Restores true Android Auto theme switching:
  - Light: OpenFreeMap Liberty
  - Dark: OpenFreeMap Dark
  - Automatic: follows the Android Auto host day/night mode
- Keeps dark mode readable on projected displays with a subtle cool lift instead of reusing the light map.
- Rebuilds the active navigation cockpit around the approved GoVia direction:
  - full MapLibre map remains visible
  - compact responsive guidance card on the left
  - orange maneuver treatment
  - trip name, remaining distance and ETA inside the compact card
  - compact POI proximity card below guidance when relevant
  - Android Auto map controls remain host-native on the right
  - voice + End remain host-native actions
- Removes the oversized Android Auto host RoutingInfo card that obscured the map on 800x400 DHU screens.
- Rebuilds recording cockpit as a full-map view:
  - compact REC card
  - elapsed time + distance
  - compact GPS status chip
  - breadcrumb remains on the real map
  - Stop and save remains an actual Android Auto action
- Improves route visibility with an orange route plus contrast casing.
- Widens the follow-camera context to zoom 15.7 / tilt 32° for better road visibility around the rider.
- Updates Android Auto regression tests and static verifier for the new cockpit architecture.
- Version: 0.1.35+36.
