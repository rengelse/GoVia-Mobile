# GoVia Mobile v0.1.127+128 – Flutter Analyze Gate Fix

- Fixes the only `flutter analyze` issue in `test/navigation_completion_flow_test.dart` by using the project-required single-quoted literal.
- No production, navigation, simulator, voice, Android Auto or trip-completion code changes from v0.1.126.
- v0.1.126 had already passed all 80 Flutter tests and the native JVM unit-test build; the release gate failed solely because `flutter analyze` returned non-zero for the lint.
- Keeps the v0.1.125 Ferrostar runtime/device-test baseline unchanged.
