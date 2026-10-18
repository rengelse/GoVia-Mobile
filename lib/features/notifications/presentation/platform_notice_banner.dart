import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../data/public_notice_service.dart';
import '../domain/platform_operations_notice.dart';

/// Authenticated banner; the user can dismiss it across all their devices.
class PlatformNoticeBanner extends StatelessWidget {
  const PlatformNoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final notice = state.activePlatformNotice;
    if (notice == null) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: _NoticePanel(
        notice: notice,
        onOpen: () => state.setShellIndex(1),
        onDismiss: () async {
          final successful = await state.dismissPlatformNotice(notice.id);
          if (!successful && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kunne ikke skjule driftsmeldingen. Prøv igjen.')),
            );
          }
        },
      ),
    );
  }
}

/// Before login: only critical public announcements from Caddy's snapshot.
class PublicPlatformNoticeBanner extends StatefulWidget {
  const PublicPlatformNoticeBanner({super.key});

  @override
  State<PublicPlatformNoticeBanner> createState() => _PublicPlatformNoticeBannerState();
}

class _PublicPlatformNoticeBannerState extends State<PublicPlatformNoticeBanner>
    with WidgetsBindingObserver {
  final PublicNoticeService _service = PublicNoticeService();
  Timer? _timer;
  PlatformOperationsNotice? _notice;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(_refresh()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final latest = await _service.fetchCriticalNotice();
      if (mounted) setState(() => _notice = latest);
    } catch (_) {
      // Do not display stale warnings if the public endpoint is unavailable.
      if (mounted) setState(() => _notice = null);
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    if (notice == null || !notice.isActiveAt(DateTime.now())) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: _NoticePanel(notice: notice),
    );
  }
}

class _NoticePanel extends StatelessWidget {
  const _NoticePanel({required this.notice, this.onOpen, this.onDismiss});

  final PlatformOperationsNotice notice;
  final VoidCallback? onOpen;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final incident = notice.kind == 'incident';
    final color = incident ? GoViaColors.red : notice.kind == 'planned_maintenance' ? GoViaColors.orange : GoViaColors.cyan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            border: Border.all(color: color.withValues(alpha: .6)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(incident ? Icons.warning_amber_rounded : Icons.campaign_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notice.title.isEmpty ? 'Driftsmelding fra GoVia' : notice.title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (notice.message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(notice.message, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (onOpen != null)
                        TextButton(
                          onPressed: onOpen,
                          child: const Text('Se i Varsler'),
                        ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: 'Skjul driftsmelding for min bruker',
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
