# GoVia Mobile v0.1.4 – Deterministic Brand Asset CI

- Fixes the remaining GitHub Actions failure in the Desktop GoVia brand asset test.
- The widget/unit test now verifies the canonical asset source file directly instead of using `rootBundle` in a headless test isolate.
- CI still verifies the brand files explicitly before analyze/test.
- Normal pushes and pull requests now build an unsigned debug APK, which is the real Flutter bundling/build verification.
- Tagged releases still build the signed release APK and SHA-256 artifact as before.
- No runtime UI, backend, RPi or Supabase changes.
