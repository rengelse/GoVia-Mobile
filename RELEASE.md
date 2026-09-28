# GoVia Mobile v0.1.78+79

## Navigation test hardening

- Updated stale navigation source-contract tests after route matching and arrival ownership moved into `GoViaNavigationEngine`.
- Added behavioral tests proving arrival requires three consecutive credible GPS fixes.
- Added a behavioral reset test proving two arrival fixes are discarded after moving clearly away from the destination.
- Added verifier guards so the old `_matchToRoute`, `_distanceFromRoute`, and screen-owned arrival assertions cannot silently return.
