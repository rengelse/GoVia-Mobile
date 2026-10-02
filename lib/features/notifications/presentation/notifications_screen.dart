import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../domain/govia_notification.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.notifications;
    final unread = state.unreadNotificationCount;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final today = items.where((item) => !item.createdAt.isBefore(startOfToday)).toList(growable: false);
    final earlier = items.where((item) => item.createdAt.isBefore(startOfToday)).toList(growable: false);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          if (items.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    unread == 0 ? 'Alt er lest' : '$unread ulest${unread == 1 ? '' : 'e'}',
                    style: const TextStyle(color: GoViaColors.muted),
                  ),
                ),
                TextButton.icon(
                  onPressed: unread == 0 ? null : state.markAllNotificationsRead,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Merk alle som lest'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Flere valg',
                  onSelected: (value) async {
                    if (value != 'clear') return;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Tøm varsler?'),
                        content: const Text('Alle varsler fjernes fra denne enheten.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Avbryt')),
                          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Tøm')),
                        ],
                      ),
                    );
                    if (confirmed == true) await state.clearNotifications();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'clear', child: Text('Tøm varsler')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (items.isEmpty)
            const _EmptyNotifications()
          else ...[
            if (today.isNotEmpty) ...[
              const _SectionLabel('I dag'),
              for (final item in today) _NotificationTile(notification: item),
            ],
            if (earlier.isNotEmpty) ...[
              if (today.isNotEmpty) const SizedBox(height: 12),
              const _SectionLabel('Tidligere'),
              for (final item in earlier) _NotificationTile(notification: item),
            ],
          ],
      ],
    );

    if (embedded) {
      return SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Varsler', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 18),
              content,
            ],
          ),
        ),
      );
    }

    return GoViaScreen(title: 'Varsler', child: content);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: GoViaColors.muted)),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final GoViaNotification notification;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final presentation = _presentation(notification.type);
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.archive_outlined, color: Colors.redAccent),
      ),
      onDismissed: (_) => state.archiveNotification(notification.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await state.markNotificationRead(notification.id);
              if (!context.mounted) return;
              await _openTarget(context, notification);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: presentation.color.withValues(alpha: .12),
                        child: Icon(presentation.icon, color: presentation.color),
                      ),
                      if (!notification.isRead)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: GoViaColors.orange, shape: BoxShape.circle, border: Border.all(color: GoViaColors.panel, width: 2)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(fontWeight: notification.isRead ? FontWeight.w700 : FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_relativeTime(notification.createdAt), style: const TextStyle(color: GoViaColors.muted, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(notification.body, style: const TextStyle(color: GoViaColors.muted, height: 1.35)),
                        if (notification.target.type != GoViaNotificationTargetType.none) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_targetLabel(notification.target.type), style: const TextStyle(color: GoViaColors.cyan, fontWeight: FontWeight.w800, fontSize: 12)),
                              const SizedBox(width: 2),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: GoViaColors.cyan),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Arkiver',
                    onPressed: () => state.archiveNotification(notification.id),
                    icon: const Icon(Icons.archive_outlined, size: 20, color: GoViaColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTarget(BuildContext context, GoViaNotification item) async {
    final state = AppScope.of(context);
    final targetTrip = state.tripById(item.target.tripId);
    if (targetTrip != null && state.activeTrip?.id != targetTrip.id) {
      await state.selectTrip(targetTrip);
      if (!context.mounted) return;
    }
    switch (item.target.type) {
      case GoViaNotificationTargetType.trip:
        if (targetTrip != null) Navigator.pushNamed(context, AppRoutes.trip, arguments: targetTrip);
      case GoViaNotificationTargetType.stage:
        final stage = state.stageById(item.target.stageId, tripId: item.target.tripId);
        if (stage != null) Navigator.pushNamed(context, AppRoutes.stage, arguments: stage);
      case GoViaNotificationTargetType.group:
        Navigator.pushNamed(context, AppRoutes.groupLive);
      case GoViaNotificationTargetType.weather:
        Navigator.pushNamed(context, AppRoutes.weather);
      case GoViaNotificationTargetType.offline:
        Navigator.pushNamed(context, AppRoutes.offline);
      case GoViaNotificationTargetType.chat:
        Navigator.pushNamed(context, AppRoutes.chat);
      case GoViaNotificationTargetType.none:
        break;
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 54),
        child: Center(
          child: Column(
            children: const [
              Icon(Icons.notifications_none_rounded, size: 62, color: GoViaColors.muted),
              SizedBox(height: 14),
              Text('Ingen varsler', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              SizedBox(height: 6),
              Text('Viktige hendelser fra turene dine vises her.', style: TextStyle(color: GoViaColors.muted)),
            ],
          ),
        ),
      );
}

({IconData icon, Color color}) _presentation(GoViaNotificationType type) => switch (type) {
      GoViaNotificationType.trip => (icon: Icons.route_outlined, color: GoViaColors.orange),
      GoViaNotificationType.navigation => (icon: Icons.navigation_outlined, color: GoViaColors.blue),
      GoViaNotificationType.group => (icon: Icons.groups_2_outlined, color: GoViaColors.cyan),
      GoViaNotificationType.weather => (icon: Icons.cloud_outlined, color: GoViaColors.cyan),
      GoViaNotificationType.offline => (icon: Icons.download_done_outlined, color: GoViaColors.green),
      GoViaNotificationType.system => (icon: Icons.info_outline_rounded, color: GoViaColors.muted),
    };

String _targetLabel(GoViaNotificationTargetType type) => switch (type) {
      GoViaNotificationTargetType.trip => 'Åpne tur',
      GoViaNotificationTargetType.stage => 'Åpne etappe',
      GoViaNotificationTargetType.group => 'Åpne gruppe',
      GoViaNotificationTargetType.weather => 'Åpne vær',
      GoViaNotificationTargetType.offline => 'Åpne offline',
      GoViaNotificationTargetType.chat => 'Åpne chat',
      GoViaNotificationTargetType.none => '',
    };

String _relativeTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt);
  if (difference.isNegative || difference.inMinutes < 1) return 'Nå';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min';
  if (difference.inHours < 24) return '${difference.inHours} t';
  if (difference.inDays == 1) return 'I går';
  if (difference.inDays < 7) return '${difference.inDays} d';
  return '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}';
}
