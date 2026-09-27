# GoVia Mobile v0.1.38 – CI Test Contract Cleanup

Version: `0.1.38+39`

## Changes
- Reworks the Android Auto cockpit test so it validates the functional contract instead of fragile UI copy.
- Ensures active navigation uses the GoVia map overlay and does not enable Android Auto host RoutingInfo cards.
- Ensures the overlay supports both navigation and recording modes without depending on literal labels such as `Opptak pågår`.
- No runtime feature change from v0.1.37.

## CI intent
The Android Auto tests should catch architectural regressions, not fail because presentation text or internal wording changes.
