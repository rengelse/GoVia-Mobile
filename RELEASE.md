# GoVia Mobile v0.1.64+65

## Android Auto – documented surface lifecycle fix

- Reworked Android Auto map rendering to follow the documented Car App lifecycle instead of owning a SurfaceCallback per Screen.
- `GoViaCarSession` now owns one persistent `GoViaCarMapSurface` for the full car session.
- `AppManager.setSurfaceCallback(...)` is registered once for the session and cleared only when the session is destroyed.
- Home, Trips, Preview, Navigation and Recording screens now only update mode/data/control callbacks on the shared renderer.
- Repeated `onSurfaceAvailable()` callbacks no longer destroy and recreate MapLibre/Presentation/VirtualDisplay when only surface size/DPI or the host surface binding changes.
- Existing VirtualDisplay is resized/rebound in place; full renderer teardown happens only on `onSurfaceDestroyed()` or session shutdown.
- Host `Surface` references are explicitly released when replaced/destroyed.
- No change to the approved GoVia Android Auto UI, search flow or navigation behavior.

Version: **0.1.64+65**
