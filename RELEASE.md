# GoVia Mobile v0.1.50+51

## Android Auto stable overview reset

- Rebased directly on v0.1.47, the last known working Android Auto baseline.
- Removed the separate Android Auto home step: Car App now opens directly on Trips.
- Trips overview has four top controls: Planlagt, Aktiv, Fullført, Ta opp.
- Ta opp opens the existing recording flow.
- Existing navigation cockpit and guidance-card cleanup from v0.1.47 are preserved.
- No process isolation, AtomicFile state bridge, or MapWithContentTemplate changes from v0.1.48/v0.1.49 are included.
