# GoVia Mobile v0.1.94+95 Maneuver Intelligence v1.1 Voice Restore CI Repair

Maneuver Intelligence v1.1 fixes a voice regression from v0.1.93: only the explicit `geometry-emergency` fallback is silent. Normalized `geometry` maneuvers remain voice-actionable, including structured roundabouts and exits. This restores navigation voice without re-enabling the removed 35-degree synthetic-turn generator.

Maneuver Intelligence v1 applies OSRM-style maneuver semantics before voice output: informational `new_name`/`notification` steps are silent, `continue` never becomes a left/right turn just because the road curves, and geometry-only emergency guidance can no longer synthesize spoken turns. Structured roundabout, ramp, fork, merge and exit semantics remain actionable.

Simulator compile repair: `_routeLength()` now lives with the simulator route parser that uses it; the dead controller copy is removed and guarded by the verifier.

Navigation Experience v1.1 focuses on guidance semantics and motion quality. Roundabouts and motorway exits now retain their semantic meaning even when exit numbers are missing; generic derived maneuvers have a constrained instruction fallback instead of blindly becoming slight turns. Phone camera following uses smoothed target/bearing/zoom with longer linear easing, and Android keeps the screen awake for the full active-navigation lifecycle.

This is a CI candidate until the full GitHub acceptance gate is green.


Navigation simulator scenarios are resolved through the normal GoVia road-routing API before GPS playback, so simulator movement follows real route geometry and provider maneuvers.
