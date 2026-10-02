import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/storage/local_store.dart';
import 'package:govia_mobile/features/notifications/data/notification_repository.dart';
import 'package:govia_mobile/features/notifications/domain/govia_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('notification model preserves read state and deep-link target', () {
    final createdAt = DateTime.utc(2026, 10, 2, 8, 30);
    final readAt = createdAt.add(const Duration(minutes: 4));
    final original = GoViaNotification(
      id: 'route-1',
      type: GoViaNotificationType.navigation,
      title: 'Ruten er oppdatert',
      body: 'Etappe 2 bruker ny rute.',
      createdAt: createdAt,
      readAt: readAt,
      priority: GoViaNotificationPriority.important,
      target: const GoViaNotificationTarget(
        type: GoViaNotificationTargetType.stage,
        tripId: 'trip-1',
        stageId: 'stage-2',
      ),
      metadata: const {'source': 'runtime'},
    );

    final decoded = GoViaNotification.fromJson(original.toJson());
    expect(decoded.id, original.id);
    expect(decoded.type, GoViaNotificationType.navigation);
    expect(decoded.isRead, isTrue);
    expect(decoded.readAt, readAt);
    expect(decoded.target.type, GoViaNotificationTargetType.stage);
    expect(decoded.target.tripId, 'trip-1');
    expect(decoded.target.stageId, 'stage-2');
    expect(decoded.metadata['source'], 'runtime');
  });

  test('notification repository persists newest-first inbox', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    final repository = NotificationRepository(store);
    final older = GoViaNotification(
      id: 'older',
      type: GoViaNotificationType.system,
      title: 'Eldre',
      body: 'Eldre varsel',
      createdAt: DateTime.utc(2026, 10, 1),
    );
    final newer = GoViaNotification(
      id: 'newer',
      type: GoViaNotificationType.trip,
      title: 'Nyere',
      body: 'Nyere varsel',
      createdAt: DateTime.utc(2026, 10, 2),
    );

    await repository.save([older, newer]);
    final loaded = repository.load();
    expect(loaded.map((item) => item.id).toList(), ['newer', 'older']);
  });

  test('notification screen contains no legacy dummy feed', () {
    final source = File('lib/features/notifications/presentation/notifications_screen.dart').readAsStringSync();
    expect(source, isNot(contains('Marius ble med på turen.')));
    expect(source, isNot(contains('Økende vind etter kl. 17.')));
    expect(source, contains('state.notifications'));
    expect(source, contains('markAllNotificationsRead'));
    expect(source, contains('archiveNotification'));
  });

  test('shell exposes unread notification badge on Varsler destination', () {
    final source = File('lib/app/shell_screen.dart').readAsStringSync();
    expect(source, contains('unreadCount: state.unreadNotificationCount'));
    expect(source, contains("label: 'Varsler'"));
    expect(source, contains('badgeCount: unreadCount'));
    expect(source, contains("badgeCount > 99 ? '99+' : '\$badgeCount'"));
  });
}
