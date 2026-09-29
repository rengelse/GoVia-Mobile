# GoVia Mobile v0.1.90+91 CI Candidate

## Navigation Experience v1.1 – Guidance Semantics & Motion

- Roundabouts no longer fall through to generic slight-left/right instructions when `exit` is missing.
- Motorway `off_ramp` / `exit` maneuvers without exit numbers now say `Ta neste avkjøring` instead of a generic turn.
- Structured maneuver type remains authoritative; instruction text is only an emergency semantic fallback for generic/derived maneuvers.
- Android Auto maneuver icons use the same semantic classification as spoken guidance.
- Phone camera target, heading and zoom are smoothed; camera transitions use longer linear easing for less stop/start motion.
- Active phone navigation now sets Android `FLAG_KEEP_SCREEN_ON`; the flag is cleared when navigation stops, finishes or the screen is disposed.
- Added Dart and native Kotlin behavior tests for roundabout and motorway-exit regressions.

## Gate

This package remains a CI candidate until verifier, Flutter analyze/tests and native app unit tests are all green in GitHub Actions.
