import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

class ApiClient {
  ApiClient({http.Client? client, this.accessTokenProvider}) : _client = client ?? http.Client();
  final http.Client _client;
  final Future<String?> Function()? accessTokenProvider;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(_uri(path), headers: await _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(String path, Object? body) async {
    final response = await _client.post(_uri(path), headers: await _headers(), body: jsonEncode(body ?? const {}));
    return _decode(response);
  }

  Future<Map<String, dynamic>> domain(String repository, String method, List<Object?> args) =>
      postJson('/api/v1/domain/$repository/$method', {'args': args});

  Future<Map<String, String>> _headers() async {
    final token = await accessTokenProvider?.call();
    return {
      'accept': 'application/json',
      'content-type': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
      'x-govia-client': 'mobile',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? raw;
    try { raw = jsonDecode(response.body); } catch (_) { raw = null; }
    final json = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      throw ApiException(
        error is Map ? (error['message']?.toString() ?? 'API-feil') : 'API-feil ${response.statusCode}',
        statusCode: response.statusCode,
        code: error is Map ? error['code']?.toString() : null,
      );
    }
    return json;
  }
}
