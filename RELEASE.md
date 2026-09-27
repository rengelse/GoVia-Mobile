# v0.1.46 – Android Auto Duplicate Host Controls Cleanup

- Removes the duplicate grey Android Auto navigation controls from the active cockpit.
- Removes host sound and `Avslutt` actions; GoVia surface controls remain the single source of truth.
- Removes the host map action strip, so host zoom/recenter buttons no longer cover the GoVia control stack.
- Keeps one neutral `Action.APP_ICON` only because `NavigationTemplate` requires a non-empty template `ActionStrip`.
- Keeps GoVia sound, zoom +, zoom -, recenter and stop controls in the custom cockpit overlay.
- Adds regression assertions preventing duplicate host controls from returning.

## Version
- App: 0.1.46+47
- Tag: v0.1.46
