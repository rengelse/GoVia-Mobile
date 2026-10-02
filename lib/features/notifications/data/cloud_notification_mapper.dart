import '../domain/govia_notification.dart';

class CloudNotificationMapper {
  const CloudNotificationMapper._();

  static GoViaNotification? fromTripNotificationRow(
    Map<String, dynamic> row, {
    required String currentUserId,
  }) {
    final id = row['id']?.toString() ?? '';
    final tripId = (row['trip_id'] ?? row['tripId'])?.toString() ?? '';
    final actorId = (row['actor_id'] ?? row['actorId'])?.toString();
    final recipients = _stringList(row['recipients']);
    if (id.isEmpty || tripId.isEmpty || currentUserId.isEmpty) return null;

    // The actor already knows about their own action. Keep system-generated
    // events (actor_id == null) eligible for delivery.
    if (actorId != null && actorId.isNotEmpty && actorId == currentUserId) return null;
    if (!recipients.contains(currentUserId)) return null;

    final cloudType = row['type']?.toString() ?? 'trip_updated';
    final targetPage = (row['target_page'] ?? row['targetPage'])?.toString();
    final targetStageId = (row['target_stage_id'] ?? row['targetStageId'])?.toString();
    final targetId = (row['target_id'] ?? row['targetId'])?.toString();
    final readBy = _stringList(row['read_by'] ?? row['readBy']);
    final createdAt = DateTime.tryParse((row['created_at'] ?? row['createdAt'])?.toString() ?? '') ?? DateTime.now();

    return GoViaNotification(
      id: 'cloud-$id',
      type: _typeFor(cloudType),
      title: row['title']?.toString().trim().isNotEmpty == true ? row['title'].toString() : 'Tur oppdatert',
      body: (row['message'] ?? row['body'])?.toString() ?? '',
      createdAt: createdAt,
      readAt: readBy.contains(currentUserId) ? createdAt : null,
      priority: cloudType.startsWith('attention_') ? GoViaNotificationPriority.important : GoViaNotificationPriority.normal,
      target: _targetFor(
        tripId: tripId,
        targetPage: targetPage,
        targetStageId: targetStageId,
      ),
      metadata: {
        'source': 'trip_notifications',
        'cloudId': id,
        'cloudType': cloudType,
        if (actorId != null && actorId.isNotEmpty) 'actorUserId': actorId,
        if (targetPage != null && targetPage.isNotEmpty) 'targetPage': targetPage,
        if (targetId != null && targetId.isNotEmpty) 'targetId': targetId,
        'readBy': readBy,
      },
    );
  }

  static List<String> _stringList(Object? raw) => raw is List
      ? raw.map((value) => value.toString()).where((value) => value.isNotEmpty).toList(growable: false)
      : const [];

  static GoViaNotificationType _typeFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('weather')) return GoViaNotificationType.weather;
    if (value.contains('route') || value.contains('stage') || value.contains('stop') || value.contains('lodging')) {
      return GoViaNotificationType.navigation;
    }
    if (value.contains('member') || value.contains('chat') || value.contains('discussion') || value.contains('poll') || value.contains('reply')) {
      return GoViaNotificationType.group;
    }
    return GoViaNotificationType.trip;
  }

  static GoViaNotificationTarget _targetFor({
    required String tripId,
    String? targetPage,
    String? targetStageId,
  }) {
    if (targetStageId != null && targetStageId.isNotEmpty) {
      return GoViaNotificationTarget(type: GoViaNotificationTargetType.stage, tripId: tripId, stageId: targetStageId);
    }
    final page = targetPage?.toLowerCase() ?? '';
    if (page.contains('weather') || page.contains('vær')) {
      return GoViaNotificationTarget(type: GoViaNotificationTargetType.weather, tripId: tripId);
    }
    if (page.contains('chat') || page.contains('discussion')) {
      return GoViaNotificationTarget(type: GoViaNotificationTargetType.chat, tripId: tripId);
    }
    if (page.contains('participant') || page.contains('member') || page.contains('group')) {
      return GoViaNotificationTarget(type: GoViaNotificationTargetType.group, tripId: tripId);
    }
    return GoViaNotificationTarget(type: GoViaNotificationTargetType.trip, tripId: tripId);
  }
}
