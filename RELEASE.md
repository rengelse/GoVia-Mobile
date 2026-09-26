# GoVia Mobile v0.1.3 – Brand Asset CI Hardening

- Replaces the fragile headless PNG render assertion with deterministic bundle verification.
- GoViaLogo now exposes one canonical Desktop brand asset path used by both runtime and tests.
- GitHub Actions verifies both GoVia brand assets exist before Flutter analyze/test.
- No backend, RPi or Supabase changes.
