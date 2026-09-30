# GoVia Mobile v0.1.107+108 – Phone Map Modes & Voice Regression Fix

Adds one cycling map-view control to phone navigation: Follow/Perspective → North up → Overview → Follow/Perspective.

- Reuses the existing MapLibre navigation camera.
- Perspective keeps heading-follow, tilt and adaptive zoom/look-ahead.
- North up follows position in 2D with bearing locked north.
- Overview frames the active route and suspends follow updates until the mode changes.
- No server, speed-limit or guidance changes.
