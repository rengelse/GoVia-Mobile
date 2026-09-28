# GoVia Mobile v0.1.60+61

## Android Auto follow camera fix

- Follow/chase camera now derives heading from the active route when GPS bearing is unavailable.
- GPS bearing remains preferred when valid.
- Navigation pitch increased to 60° for a clearly visible forward-looking perspective.
- Low-speed follow zoom tightened so the vehicle sits closer to the road ahead.
- Recenter returns to the same route-aware follow camera.
- Version checks remain dynamic and release workflow is preserved.

## Android Auto independent startup/state stability
- Preserve the last valid Android Auto snapshot while the phone app hydrates.
- Do not sync car state for phone-only UI navigation.
- Deduplicate semantically identical Android Auto payloads before crossing the MethodChannel.
- Keep DHU usable from the persisted native bridge without requiring the phone UI to be opened first.
