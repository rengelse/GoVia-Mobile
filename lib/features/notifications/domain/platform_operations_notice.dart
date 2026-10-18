/// Platform-wide notices published by GoVia Admin (independent of trip events).
class PlatformOperationsNotice {
  const PlatformOperationsNotice({
    required this.id,
    required this.enabled,
    required this.kind,
    required this.target,
    required this.title,
    required this.message,
    required this.publishedAt,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final bool enabled;
  final String kind;
  final String target;
  final String title;
  final String message;
  final DateTime publishedAt;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get forMobile => target == 'mobile' || target == 'all';
  bool get critical => kind == 'incident' || kind == 'planned_maintenance';

  bool isActiveAt(DateTime now) =>
      enabled && forMobile &&
      (startsAt == null || !now.isBefore(startsAt!)) &&
      (endsAt == null || now.isBefore(endsAt!));

  /// A disabled, future, or expired latest record suppresses the old banner.
  /// Select the latest *targeted* record before evaluating eligibility.
  static PlatformOperationsNotice? latestMobile(Iterable<PlatformOperationsNotice> notices) {
    PlatformOperationsNotice? latest;
    for (final notice in notices) {
      if (!notice.forMobile) continue;
      if (latest == null || notice.publishedAt.isAfter(latest.publishedAt) ||
          (notice.publishedAt.isAtSameMomentAs(latest.publishedAt) && notice.id.compareTo(latest.id) > 0)) {
        latest = notice;
      }
    }
    return latest;
  }

  static PlatformOperationsNotice? fromDatabase(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final published = DateTime.tryParse(row['published_at']?.toString() ?? '');
    if (id.isEmpty || published == null) return null;
    return PlatformOperationsNotice(
      id: id,
      enabled: row['enabled'] == true,
      kind: row['kind']?.toString() ?? 'information',
      target: row['target']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      message: row['message']?.toString() ?? '',
      publishedAt: published,
      startsAt: DateTime.tryParse(row['starts_at']?.toString() ?? ''),
      endsAt: DateTime.tryParse(row['ends_at']?.toString() ?? ''),
    );
  }

  /// Anonymous Pi/Caddy snapshot uses camelCase, NOT Supabase column names.
  static PlatformOperationsNotice? fromPublicSnapshot(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['noticePublished'] != true) return null;
    final raw = json['notice'];
    if (raw is! Map) return null;
    final value = Map<String, dynamic>.from(raw);
    return PlatformOperationsNotice(
      id: value['id']?.toString() ?? 'public-snapshot',
      enabled: value['enabled'] == true,
      kind: value['kind']?.toString() ?? 'information',
      target: value['target']?.toString() ?? '',
      title: value['title']?.toString() ?? '',
      message: value['message']?.toString() ?? '',
      publishedAt: DateTime.tryParse(value['publishedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      startsAt: DateTime.tryParse(value['startsAt']?.toString() ?? ''),
      endsAt: DateTime.tryParse(value['endsAt']?.toString() ?? ''),
    );
  }
}
