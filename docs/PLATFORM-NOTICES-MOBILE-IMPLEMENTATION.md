# GoVia Mobile – platform notifications integration (source patch)

## Provenance and release safety

- Mobile baseline supplied by user: `GoVia Mobile v0.1.146(1).zip` (`pubspec.yaml`: `0.1.146+147`).
- Back-end contract: Raspberry Pi GoVia v0.86.425 with Supabase migration `20261018200000_platform_operations_notifications.sql`.
- New candidate version: **`0.1.148+149`** (`v0.1.148` GitHub release tag). Builds on the v0.1.147 platform-notification implementation, originally derived from the user's v0.1.146 ZIP. GitHub main and the published v0.1.147 tag were checked; the lint failure in `lib/app/app_state.dart` on main was confirmed. Merge this fix on top of current main; do not overwrite unrelated subsequent commits.
- This is versioned **source code**, not a built/tested APK or a published v0.1.148 GitHub Release. The v0.1.147 release/tag already exists and must not be reused or force-updated. Run Flutter/Android acceptance checks before creating tag `v0.1.148`.
- No RPi, DNS, Caddy, Website, Desktop, SQL schema, trip data, or Android Auto code changed.

## v0.1.148 CI correction

- `lib/app/app_state.dart` `markAllNotificationsRead`: add braces to the multiline guard that failed Flutter analyze with `curly_braces_in_flow_control_structures` at line 530 in v0.1.147; no behavior change.
- `pubspec.yaml`, `README.md`, `RELEASE.md`: bump version/build and document the new tag.

## What changed

1. `lib/features/notifications/domain/platform_operations_notice.dart` – parser, target/window/tombstone logic; newest applicable Mobile/All record controls the banner even if disabled.
2. `lib/features/notifications/data/platform_notice_mapper.dart` – maps global notices into the existing notification model using `system:<uuid>` IDs, without mixing `trip_notifications`.
3. `lib/features/auth/auth_service.dart` – authenticated Supabase reads and per-user RLS-protected read/dismiss upserts. Uses existing Supabase client and publishable key; **no service-role key** in Mobile.
4. `lib/app/app_state.dart` – polling every 60 seconds, auth switch/logout cleanup, foreground refresh, banner selection and read/dismiss sync; ignores responses from a previous account or stale poll.
5. `lib/features/notifications/data/notification_repository.dart` – global user-specific notices are never written to shared local inbox cache.
6. `lib/features/notifications/data/public_notice_service.dart` – pre-login read-only Caddy static status snapshot (`https://govia.no/src/site-publication.json`), with cache-busting, no Supabase login or private state.
7. `lib/features/notifications/presentation/platform_notice_banner.dart` – mobile banner in Shell and critical public warning on login page.
8. Existing `Varsler` screen – global system notice history, unread status, archive/dismiss synced to Supabase; retry/status error text.
9. New `test/platform_operations_notices_test.dart` – target/window/tombstone/history/public endpoint/local caching tests.

## Required tests before a release

From a Flutter SDK environment on the correct final development branch:

```bash
flutter pub get
flutter analyze
flutter test
```

Then build using the Android signing workflow with **version `0.1.148+149` and new tag `v0.1.148`**, after committing this change to main and ensuring no newer commits were overwritten. This source archive is not an APK. It has not been validated with a physical device.

## Device and production verification

1. In Admin publish an enabled `Mobile` notice with no schedule; sign into the app; verify banner and a single system entry in `Varsler`.
2. Tap system entry: it becomes read; verify its `user_operations_notice_state.read_at` for the signed-in user and that state persists after restart.
3. Hide from banner/Archive from list; verify `dismissed_at` in Supabase; reboot and confirm it remains hidden.
4. Publish `All`; confirm it appears. Publish newer `Desktop` notice; Mobile banner should remain on last Mobile/All notice.
5. Publish a newer **disabled** `Mobile` notice; confirm old Mobile banner disappears, while historical entries remain as history.
6. Test future `starts_at` and expired `ends_at` windows; scheduled/expired notices must not become an active banner.
7. Sign out: system notice state must be cleared in memory; login as another user: first user's dismissal must not leak.
8. On login page, publish an active critical `Mobile`/`All` incident; confirm public snapshot warning; verify Website/Desktop-only or informational notice does not appear as critical pre-login warning.
9. Disconnect Supabase: trip notifications and offline capabilities should continue; `Varsler` reports sync failure rather than claiming that a status write worked.
10. Confirm Caddy site publishing and existing trip notification flows are unchanged.

## Known scope limits

- **No system push notifications (FCM/APNs)**. This integration displays and refreshes in-app notices while Mobile is open/active; OS-level push requires a separate secure worker, device token registration, expiry and opt-in permissions.
- Pre-login reads the public Pi/Caddy snapshot only; it is not a complete historical feed.
- `flutter analyze`, `flutter test`, Android packaging, signed install and device acceptance were **not executed** in the code-editing environment because Flutter/Dart SDK is unavailable. Static source and ZIP consistency checks are not a substitute.
