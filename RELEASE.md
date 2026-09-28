# GoVia Mobile v0.1.54+55

## Android Auto ghost-action + control safety cleanup

- Removed the visible APP_ICON host action from Trips/Home by using the same invisible required ActionStrip contract as active navigation.
- Increased spacing between right-side navigation controls.
- Moved the red stop control to a clearly separated lower position.
- Tapping stop now opens an explicit confirmation screen before ending the trip.
- Version-sensitive tests/verifier remain dynamic and synchronized with pubspec.yaml.
