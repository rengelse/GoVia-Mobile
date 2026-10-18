import '../domain/govia_notification.dart';
import '../domain/platform_operations_notice.dart';

class PlatformNoticeMapper {
  const PlatformNoticeMapper._();

  static bool isPlatformNotice(GoViaNotification notification) =>
      notification.metadata['source'] == 'platform_operations_notices' ||
      notification.id.startsWith('system:');

  static String? noticeId(GoViaNotification notification) =>
      isPlatformNotice(notification) && notification.id.startsWith('system:')
          ? notification.id.substring('system:'.length)
          : null;

  static GoViaNotification toNotification(
    PlatformOperationsNotice notice, {
    DateTime? readAt,
  }) => GoViaNotification(
        id: 'system:${notice.id}',
        type: GoViaNotificationType.system,
        title: notice.title,
        body: notice.message,
        createdAt: notice.publishedAt,
        readAt: readAt,
        priority: notice.critical
            ? GoViaNotificationPriority.important
            : GoViaNotificationPriority.normal,
        metadata: {
          'source': 'platform_operations_notices',
          'noticeId': notice.id,
          'kind': notice.kind,
        },
      );
}
