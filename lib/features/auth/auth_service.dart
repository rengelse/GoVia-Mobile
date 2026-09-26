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
    await _client?.auth.signOut();
    await _secure.deleteAll();
  }
}
