# GoVia Mobile v0.1.107+108 — Phone Map Modes & Voice Regression Fix

- Replaces parent-driven phone map mode state with local camera-state ownership in `NavigationMapCockpit`.
- One button cycles Perspective/Follow → North up → Route overview and applies the camera immediately.
- Restores actionable voice guidance while keeping weak `slight left/right` road curvature silent.
- `continue` is audible only for decisive left/right/sharp/U-turn modifiers; straight/slight continuation remains silent.
- No server, database or speed-limit pipeline changes.
