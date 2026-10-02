enum GoViaNotificationType {
  trip,
  navigation,
  group,
  weather,
  offline,
  system,
}

enum GoViaNotificationPriority { normal, important }

enum GoViaNotificationTargetType {
  none,
  trip,
  stage,
  group,
  weather,
  offline,
  chat,
}

class GoViaNotificationTarget {
  const GoViaNotificationTarget({
    required this.type,
    this.tripId,
    this.stageId,
  });

  const GoViaNotificationTarget.none()
      : type = GoViaNotificationTargetType.none,
        tripId = null,
        stageId = null;

  final GoViaNotificationTargetType type;
  final String? tripId;
  final String? stageId;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (tripId != null) 'tripId': tripId,
        if (stageId != null) 'stageId': stageId,
      };

  factory GoViaNotificationTarget.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString();
    final type = GoViaNotificationTargetType.values.where((value) => value.name == rawType).firstOrNull ?? GoViaNotificationTargetType.none;
    return GoViaNotificationTarget(
      type: type,
      tripId: json['tripId']?.toString(),
      stageId: json['stageId']?.toString(),
    );
  }
}

class GoViaNotification {
  const GoViaNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.priority = GoViaNotificationPriority.normal,
    this.target = const GoViaNotificationTarget.none(),
    this.metadata = const {},
  });

  final String id;
  final GoViaNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final GoViaNotificationPriority priority;
  final GoViaNotificationTarget target;
  final Map<String, dynamic> metadata;

  bool get isRead => readAt != null;

  GoViaNotification copyWith({
    DateTime? readAt,
    bool clearReadAt = false,
  }) =>
      GoViaNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        readAt: clearReadAt ? null : (readAt ?? this.readAt),
        priority: priority,
        target: target,
        metadata: metadata,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        if (readAt != null) 'readAt': readAt!.toIso8601String(),
        'priority': priority.name,
        'target': target.toJson(),
        'metadata': metadata,
      };

  factory GoViaNotification.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString();
    final rawPriority = json['priority']?.toString();
    final targetRaw = json['target'];
    final metadataRaw = json['metadata'];
    return GoViaNotification(
      id: json['id']?.toString() ?? '',
      type: GoViaNotificationType.values.where((value) => value.name == rawType).firstOrNull ?? GoViaNotificationType.system,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
      priority: GoViaNotificationPriority.values.where((value) => value.name == rawPriority).firstOrNull ?? GoViaNotificationPriority.normal,
      target: targetRaw is Map
          ? GoViaNotificationTarget.fromJson(Map<String, dynamic>.from(targetRaw))
          : const GoViaNotificationTarget.none(),
      metadata: metadataRaw is Map ? Map<String, dynamic>.from(metadataRaw) : const {},
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
