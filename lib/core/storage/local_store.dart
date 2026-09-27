import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;
  static Future<LocalStore> create() async => LocalStore(await SharedPreferences.getInstance());

  Future<void> writeJson(String key, Object value) => _prefs.setString(key, jsonEncode(value));
  Map<String, dynamic>? readJson(String key) {
    final text = _prefs.getString(key);
    if (text == null) return null;
    try {
      final parsed = jsonDecode(text);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (_) { return null; }
  }
  Future<void> writeString(String key, String value) => _prefs.setString(key, value);
  String? readString(String key) => _prefs.getString(key);
  Future<void> writeBool(String key, bool value) => _prefs.setBool(key, value);
  bool readBool(String key, {bool fallback = false}) => _prefs.getBool(key) ?? fallback;
  Future<void> remove(String key) => _prefs.remove(key);
}
