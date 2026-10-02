Version: v0.1.135+136
GitHub tag: v0.1.135 (prepared; not pushed from this workspace)
Release title: v0.1.135 – Map Home Theme & Layout Refinement
GitHub Desktop Summary: Refine Map Home theme/layout and add destination search
GitHub Desktop Description:
Add persisted Light/Dark/System app theme and synchronize the home MapLibre style.
Compact home overlays, hide empty discovery and raise the planning CTA.
Use shared Photon search for destinations and route selected coordinates into the planner.
Keep navigation, weather, notification badge and CI gates unchanged.

Local checks: static preflight PASS; verify_mobile PASS; CI contract verifier PASS;
Dart grammar parse PASS (syntax only; does not replace Flutter analyze).
Acceptance gate: BLOCKED (Flutter SDK unavailable).
Flutter analyze/test, JVM and Android emulator tests: NOT RUN.
GitHub CI: NOT TRIGGERED / NOT VERIFIED. No GitHub remote checkout is attached.
These ZIPs are source candidates for the existing GitHub acceptance workflow.

UPDATE: overlay on v0.1.134 repository root; contains changed/new files only.
No files are deleted by this update. No database/server change.
App theme is in Profile; existing installs retain dark default.
POI address search depends on Photon indexing. Cached trip POI has no coordinates;
selecting one searches its name, then the user selects the geocoded result.
Visual device verification of light/dark and compact layout remains necessary.
