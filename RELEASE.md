# GoVia Mobile v0.1.37 – Analyze Cleanup

## Version
`0.1.37+38`

## Fix
- Removes the unused `_previewIndex` getter and its now-unused `_sameGeometry` helper from `plan_trip_screen.dart`.
- This fixes the `flutter analyze` failure reported for v0.1.36.
- No runtime feature changes from v0.1.36.

## Retained from v0.1.36
- Simplified trip save/start flow.
- Human-readable place names via reverse geocoding.
- Android Auto cockpit/map improvements.
