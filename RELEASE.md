# v0.1.48 – Android Auto Host Button Cleanup

- Home and Turer use `MapWithContentTemplate` on Car API 7+ with no host `ActionStrip`.
- Removes the large gray host APP_ICON/BACK floating buttons that overlapped GoVia UI.
- Keeps a safe `NavigationTemplate` + required action strip fallback for older Car API hosts.
- Adds regression coverage so modern hosts cannot reintroduce duplicate floating controls.

# v0.1.47 – Android Auto Guidance Card Cleanup

- Simplifies the active-navigation guidance card to show only the next maneuver.
- Removes trip name, remaining distance and arrival time from the guidance card because those values already exist in the dedicated lower status pill.
- Keeps distance to maneuver, maneuver instruction and optional road name.
- Reduces the guidance card height to match the leaner content.
- Keeps POI card, lower arrival/remaining status pill and right-side GoVia controls unchanged.
- Adds a regression test preventing duplicated trip/status information from returning to the guidance card.

## Version
- App: 0.1.47+48
- Tag: v0.1.47
