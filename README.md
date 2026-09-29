# GoVia Mobile v0.1.91+92 CI Candidate

Navigation Experience v1.1 focuses on guidance semantics and motion quality. Roundabouts and motorway exits now retain their semantic meaning even when exit numbers are missing; generic derived maneuvers have a constrained instruction fallback instead of blindly becoming slight turns. Phone camera following uses smoothed target/bearing/zoom with longer linear easing, and Android keeps the screen awake for the full active-navigation lifecycle.

This is a CI candidate until the full GitHub acceptance gate is green.


Navigation simulator scenarios are resolved through the normal GoVia road-routing API before GPS playback, so simulator movement follows real route geometry and provider maneuvers.
