import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';

class AuthService {
  AuthService._(this._client);
  final SupabaseClient? _client;
  static const _secure = FlutterSecureStorage();

  static Future<AuthService> create() async {
    if (!AppConfig.hasSupabase) return AuthService._(null);
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseClientKey);
    return AuthService._(Supabase.instance.client);
  }

  bool get configured => _client != null;
  User? get user => _client?.auth.currentUser;
  bool get signedIn => user != null;
  Stream<AuthState>? get authChanges => _client?.auth.onAuthStateChange;
  Future<String?> accessToken() async => _client?.auth.currentSession?.accessToken;

  RealtimeChannel? _notificationChannel;

  Future<List<Map<String, dynamic>>> listTripNotifications({int limit = 250}) async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null) return const [];
    final rows = await client
        .from('trip_notifications')
        .select()
        .contains('recipients', [uid])
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  Future<void> markTripNotificationRead(String notificationId, {List<String> readBy = const []}) async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null || notificationId.isEmpty) return;
    final current = await client.from('trip_notifications').select('read_by').eq('id', notificationId).maybeSingle();
    final remoteReadBy = current?['read_by'];
    final next = <String>{
      ...readBy,
      if (remoteReadBy is List) ...remoteReadBy.map((value) => value.toString()),
      uid,
    }.toList(growable: false);
    await client.from('trip_notifications').update({'read_by': next}).eq('id', notificationId);
  }

  Future<void> subscribeTripNotifications(void Function(Map<String, dynamic> row) onRow) async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null) return;
    await stopTripNotificationRealtime();
    _notificationChannel = client
        .channel('govia-mobile-trip-notifications-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_notifications',
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final recipients = row['recipients'];
            if (recipients is List && recipients.map((value) => value.toString()).contains(uid)) {
              onRow(row);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trip_notifications',
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final recipients = row['recipients'];
            if (recipients is List && recipients.map((value) => value.toString()).contains(uid)) {
              onRow(row);
            }
          },
        )
        .subscribe();
  }

  Future<void> stopTripNotificationRealtime() async {
    final client = _client;
    final channel = _notificationChannel;
    _notificationChannel = null;
    if (client != null && channel != null) {
      await client.removeChannel(channel);
    }
  }

  Future<String> uploadProfileAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null) throw StateError('Du må være innlogget for å laste opp profilbilde.');
    final safeExtension = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final ext = safeExtension.isEmpty ? 'jpg' : safeExtension;
    final path = '$uid/avatar-${DateTime.now().microsecondsSinceEpoch}.$ext';
    await client.storage.from('profile-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    return client.storage.from('profile-media').getPublicUrl(path);
  }

  Future<String> uploadPublishedRoutePhoto({
    required String routeId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null) throw StateError('Du må være innlogget for å laste opp bilder.');
    final safeExtension = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final path = '$uid/$routeId/${DateTime.now().microsecondsSinceEpoch}.${safeExtension.isEmpty ? 'jpg' : safeExtension}';
    await client.storage.from('published-route-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    return path;
  }

  Future<void> removePublishedRoutePhoto(String path) async {
    final client = _client;
    if (client == null) throw StateError('Supabase er ikke konfigurert.');
    await client.storage.from('published-route-media').remove([path]);
  }

  Future<void> signIn(String email, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase er ikke konfigurert.');
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp(String email, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase er ikke konfigurert.');
    await client.auth.signUp(email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    await stopTripNotificationRealtime();
    await _client?.auth.signOut();
    await _secure.deleteAll();
  }
}
