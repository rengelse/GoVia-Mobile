# GoVia Mobile v0.1.126+127 – Navigation Simulator, Voice Language & Trip Completion Flow

- Replaces the developer simulator scenario set with explicit country-road, motorway-exit, roundabout, intersection, speed-limit, reroute and arrival scenarios.
- Simulator fallback speed-limit sections now carry path indexes, so Ferrostar annotations can consume them.
- Adds a persisted Navigation language setting under Navigation and transport: Automatic, Norsk, English.
- Phone and Android Auto TTS now localize from maneuver semantics instead of speaking mixed provider text.
- Stop navigation now asks whether to continue, stop guidance, or complete the trip/stage.
- Arrival now opens an explicit completion flow while allowing the route to remain open.
- Keeps the v0.1.125 Ferrostar runtime architecture intact.
