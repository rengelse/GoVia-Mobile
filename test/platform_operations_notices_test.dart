import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/storage/local_store.dart';
import 'package:govia_mobile/features/notifications/data/notification_repository.dart';
import 'package:govia_mobile/features/notifications/data/platform_notice_mapper.dart';
import 'package:govia_mobile/features/notifications/data/public_notice_service.dart';
import 'package:govia_mobile/features/notifications/domain/govia_notification.dart';
import 'package:govia_mobile/features/notifications/domain/platform_operations_notice.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18, 18);

  PlatformOperationsNotice makeNotice({
    String id = 'notice-1',
    String target = 'mobile',
    String kind = 'incident',
    bool enabled = true,
    DateTime? publishedAt,
    DateTime? startsAt,
    DateTime? endsAt,
  }) => PlatformOperationsNotice(
        id: id,
        enabled: enabled,
        kind: kind,
        target: target,
        title: 'Test',
        message: 'Driftsmelding',
        publishedAt: publishedAt ?? now,
        startsAt: startsAt,
        endsAt: endsAt,
      );

  test('Mobile/All only; schedule includes start, excludes end', () {
    expect(makeNotice(target: 'desktop').isActiveAt(now), false);
    expect(makeNotice(target: 'website').isActiveAt(now), false);
    expect(makeNotice(target: 'all').isActiveAt(now), true);
    expect(makeNotice(startsAt: now).isActiveAt(now), true);
    expect(makeNotice(startsAt: now.add(const Duration(minutes: 1))).isActiveAt(now), false);
    expect(makeNotice(endsAt: now).isActiveAt(now), false);
  });

  test('new disabled Mobile tombstone hides old All; Desktop record ignored', () {
    final old = makeNotice(target: 'all', id: 'old', publishedAt: now);
    final disabled = makeNotice(id: 'disabled', enabled: false, publishedAt: now.add(const Duration(seconds: 1)));
    final desktop = makeNotice(id: 'desktop', target: 'desktop', publishedAt: now.add(const Duration(seconds: 2)));
    final latest = PlatformOperationsNotice.latestMobile([old, disabled, desktop]);
    expect(latest?.id, 'disabled');
    expect(latest?.isActiveAt(now), false);
    expect(PlatformOperationsNotice.latestMobile([old, desktop])?.id, 'old');
  });

  test('a newer inactive window does not revive an older banner', () {
    final old = makeNotice(target: 'all', id: 'old', publishedAt: now);
    final future = makeNotice(id: 'future',
        publishedAt: now.add(const Duration(seconds: 1)),
        startsAt: now.add(const Duration(hours: 1)));
    final latest = PlatformOperationsNotice.latestMobile([old, future]);
    expect(latest?.id, 'future');
    expect(latest?.isActiveAt(now), false);
  });

  test('system history carries stable ID, priority, read state without trip target', () {
    final read = now.add(const Duration(minutes: 2));
    final item = PlatformNoticeMapper.toNotification(makeNotice(), readAt: read);
    expect(item.id, 'system:notice-1');
    expect(item.type, GoViaNotificationType.system);
    expect(item.priority, GoViaNotificationPriority.important);
    expect(item.readAt, read);
    expect(item.target.type, GoViaNotificationTargetType.none);
    expect(PlatformNoticeMapper.noticeId(item), 'notice-1');
  });

  test('public snapshot uses camelCase, published flag, and Mobile target', () {
    final notice = PlatformOperationsNotice.fromPublicSnapshot({
      'version': 1,
      'noticePublished': true,
      'notice': {
        'enabled': true,
        'kind': 'incident',
        'target': 'mobile',
        'title': 'Info',
        'message': 'Example',
        'startsAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'endsAt': now.add(const Duration(minutes: 1)).toIso8601String(),
      },
    });
    expect(notice?.isActiveAt(now), true);
    expect(PlatformOperationsNotice.fromPublicSnapshot({'version': 1, 'noticePublished': false, 'notice': {}}), null);
  });

  test('anonymous fetch ignores informational notices, rejects stale/no-target', () async {
    final client = MockClient((request) async {
      expect(request.url.path, PublicNoticeService.statusUrl.path);
      expect(request.url.queryParameters.containsKey('t'), isTrue);
      return http.Response(jsonEncode({
        'version': 1,
        'noticePublished': true,
        'notice': {
          'enabled': true,
          'target': 'mobile',
          'kind': 'information',
          'title': 'Information',
          'message': 'Not critical',
        },
      }), 200);
    });
    final service = PublicNoticeService(client: client);
    expect(await service.fetchCriticalNotice(), isNull);
    service.dispose();
    client.close();
  });

  test('platform history is never stored locally across accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    final repository = NotificationRepository(store);
    final platform = PlatformNoticeMapper.toNotification(makeNotice());
    final local = GoViaNotification(id: 'local-1', type: GoViaNotificationType.trip,
        title: 'Tur', body: 'Etappe', createdAt: now);
    await repository.save([local, platform]);
    final restored = repository.load();
    expect(restored.map((e) => e.id), ['local-1']);
  });
}
