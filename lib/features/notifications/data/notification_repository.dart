import '../../../core/storage/local_store.dart';
import '../domain/govia_notification.dart';

class NotificationRepository {
  NotificationRepository(this.store);

  final LocalStore store;

  static const _storageKey = 'notification_center_v1';
  static const _maxStored = 250;

  List<GoViaNotification> load() {
    final root = store.readJson(_storageKey);
    final raw = root?['items'];
    if (raw is! List) return const [];
    final items = raw
        .whereType<Map>()
        .map((item) => GoViaNotification.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(items);
  }

  Future<void> save(List<GoViaNotification> notifications) async {
    final ordered = [...notifications]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limited = ordered.take(_maxStored).toList(growable: false);
    await store.writeJson(_storageKey, {
      'version': 1,
      'items': [for (final item in limited) item.toJson()],
    });
  }
}
