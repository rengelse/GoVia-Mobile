import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/platform_operations_notice.dart';

/// Read-only, unauthenticated status path. Never contains per-user state.
class PublicNoticeService {
  PublicNoticeService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static final Uri statusUrl = Uri.parse('https://govia.no/src/site-publication.json');
  final http.Client _client;
  final bool _ownsClient;

  Future<PlatformOperationsNotice?> fetchCriticalNotice() async {
    // Public status file is published by Pi/Caddy independently of Supabase.
    final freshUrl = statusUrl.replace(queryParameters: {
      't': '${DateTime.now().millisecondsSinceEpoch}',
    });
    final response = await _client.get(freshUrl, headers: {
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    final notice = PlatformOperationsNotice.fromPublicSnapshot(Map<String, dynamic>.from(json));
    if (notice == null || !notice.critical || !notice.isActiveAt(DateTime.now())) return null;
    return notice;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
