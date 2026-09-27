# GoVia Mobile v0.1.33 – Android Auto Map Test Sync

## v0.1.33
- Synchronizes Android Auto cockpit/theme regression tests with the readable-map implementation.
- Preserves the v0.1.32 runtime map/readability changes.
- New revision/tag to keep GitHub release history clean.

- Replaces the unreadable stock OpenFreeMap dark style on projected displays with a high-legibility Liberty base plus a controlled navy night veil.
- Keeps roads, labels, junctions and area geometry readable in dark/automatic Android Auto mode.
- Tunes follow camera to zoom 16.0 / tilt 38° for better road context on 800×400 and similar displays.
- Strengthens active route visibility with a wider orange route line.
- Reworks recording cockpit to use `MapWithContentTemplate` on Car API 7+ instead of pretending recording is turn-by-turn navigation.
- Recording cockpit now shows REC, elapsed time, driven distance, GPS state and `Stopp og lagre` over the real map.
- Breadcrumb recording remains rendered on MapLibre.
- Existing GoVia brand/logo resources are unchanged and remain authoritative.
