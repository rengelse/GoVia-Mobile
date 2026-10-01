# GoVia Mobile v0.1.114+115 – Ferrostar Authoritative Navigation Runtime

GoVia Mobile now uses Ferrostar Core as the single authoritative navigation runtime for phone and Android Auto. TomTom/GoVia remains the route provider. Progress, snapping, step advancement, arrival, deviation, speed-limit annotations and spoken maneuver state are produced by the same native runtime.

Legacy Dart NavigationSession, Kotlin NavigationCoreV2 and GuidanceV1 implementations have been removed rather than retained as fallbacks. Provider maneuvers are strictly anchored; unknown speed limits remain unknown.

See `docs/FERROSTAR-PRODUCTION-RUNTIME.md` for the production contract and CI gates.
