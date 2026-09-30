# Ferrostar Migration Decision Gate — v0.1.113

This gate remains isolated from the production navigation runtime.

## Proven by the previous green v0.1.112 gate

- Ferrostar Core loads and runs on a real Android emulator.
- GoVia canonical route data can be adapted into a real Ferrostar NavigationSession.
- The same synthetic route trace can be processed by GoVia NavigationCoreV2 and Ferrostar.

## Additional v0.1.113 acceptance criteria

1. GoVia progress does not regress on the reference trace.
2. Ferrostar remaining distance does not regress unexpectedly.
3. Provider-anchored speed annotations 80 -> 60 -> 40 km/h are surfaced by the Ferrostar runtime in route order.
4. A weak slight-right road bend remains silent.
5. A motorway off-ramp remains actionable and keeps exit number 7.
6. A roundabout keeps exit number 2.
7. Repeated credible off-route fixes must result in Ferrostar deviation state instead of silent perpetual snapping.
8. A machine-readable runtime report is exported as the GitHub Actions artifact `govia-ferrostar-runtime-report`.

Passing this gate is evidence for proceeding to a controlled production-runtime migration design. It is not yet a production runtime switch.
