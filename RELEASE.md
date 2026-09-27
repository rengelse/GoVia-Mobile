# GoVia Mobile v0.1.13 – Voice Navigation Test Hardening

- Runtime navigation logic unchanged.
- Fixes the voice-navigation regression test so it validates Norwegian language availability + fallback instead of requiring a brittle literal `setLanguage(\'nb-NO\')` call.
- Expected behavior remains: prefer `nb-NO`, fall back to `no-NO`.
