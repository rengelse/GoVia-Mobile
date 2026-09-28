# GoVia Mobile v0.1.53+54

## Android Auto host-button removal

- Removed the redundant large grey host button from active navigation.
- Kept the stable `NavigationTemplate` and the GoVia-owned vertical cockpit controls.
- Navigation now supplies a protocol-valid empty required action strip instead of `Action.APP_ICON`.
- No process isolation, state-bridge, or MapWithContentTemplate changes.
- Added a regression contract so active navigation cannot reintroduce a visible host action.

---

# GoVia Mobile v0.1.52+53

## CI version-contract fix

- Updated `pubspec.yaml` to `0.1.52+53`.
- Replaced the brittle hard-coded version assertion in `android_auto_cockpit_layout_test.dart` with a dynamic consistency check sourced from `pubspec.yaml`.
- `README.md` and `RELEASE.md` must now match the `pubspec.yaml` version automatically.
- `tool/verify_mobile.py` enforces the same dynamic release-version contract.
- No runtime/UI behavior changed in this revision.

---

# GoVia Mobile v0.1.51+51

## Android Auto stable overview reset

- Rebased directly on v0.1.47, the last known working Android Auto baseline.
- Removed the separate Android Auto home step: Car App now opens directly on Trips.
- Trips overview has four top controls: Planlagt, Aktiv, Fullført, Ta opp.
- Ta opp opens the existing recording flow.
- Existing navigation cockpit and guidance-card cleanup from v0.1.47 are preserved.
- No process isolation, AtomicFile state bridge, or MapWithContentTemplate changes from v0.1.48/v0.1.49 are included.


## v0.1.51+52
- Fixed Dart analyzer unnecessary_string_escapes in Android Auto cockpit layout test.
