import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.name, required this.notes, required this.apkUrl, this.sha256Url});
  final String version;
  final String name;
  final String notes;
  final String apkUrl;
  final String? sha256Url;
}

class GithubUpdater {
  GithubUpdater({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<UpdateInfo?> check() async {
    if (!Platform.isAndroid) return null;
    final uri = Uri.parse('https://api.github.com/repos/${AppConfig.githubOwner}/${AppConfig.githubRepo}/releases/latest');
    final response = await _client.get(uri, headers: {'accept': 'application/vnd.github+json'});
    if (response.statusCode != 200) throw StateError('Kunne ikke lese GitHub Release (${response.statusCode}).');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^v'), '');
    final package = await PackageInfo.fromPlatform();
    if (!_isNewer(tag, package.version)) return null;
    final assets = (json['assets'] as List? ?? const []).whereType<Map>().toList();
    Map? apk;
    for (final asset in assets) {
      final name = (asset['name'] ?? '').toString();
      if (name.startsWith(AppConfig.githubAssetPrefix) && name.endsWith('.apk')) apk ??= asset;
    }
    if (apk == null) throw StateError('Ny release finnes, men ingen GoVia Mobile APK ble funnet.');
    final apkName = (apk['name'] ?? '').toString();
    Map? sha;
    for (final asset in assets) {
      final name = (asset['name'] ?? '').toString();
      if (name == '$apkName.sha256') { sha = asset; break; }
    }
    return UpdateInfo(
      version: tag,
      name: (json['name'] ?? 'GoVia Mobile $tag').toString(),
      notes: (json['body'] ?? '').toString(),
      apkUrl: apk['browser_download_url'].toString(),
      sha256Url: sha?['browser_download_url']?.toString(),
    );
  }

  Future<File> download(UpdateInfo info, {void Function(double value)? onProgress}) async {
    final request = http.Request('GET', Uri.parse(info.apkUrl));
    final response = await _client.send(request);
    if (response.statusCode != 200) throw StateError('APK-nedlasting feilet (${response.statusCode}).');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/GoVia-Mobile-${info.version}.apk');
    final sink = file.openWrite();
    var received = 0;
    final total = response.contentLength ?? 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.flush();
    await sink.close();
    if (info.sha256Url != null) await _verify(file, info.sha256Url!);
    return file;
  }

  Future<void> install(File apk) async {
    final result = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) throw StateError('Kunne ikke åpne Android-installasjonen: ${result.message}');
  }

  Future<void> _verify(File apk, String url) async {
    final expectedResponse = await _client.get(Uri.parse(url));
    if (expectedResponse.statusCode != 200) throw StateError('Kunne ikke hente SHA-256 kontrollsum.');
    final expected = expectedResponse.body.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final digest = sha256.convert(await apk.readAsBytes()).toString().toLowerCase();
    if (expected.isNotEmpty && expected != digest) throw StateError('SHA-256 verifikasjon feilet. Oppdateringen er ikke installert.');
  }

  bool _isNewer(String candidate, String current) {
    List<int> parse(String value) {
      final core = value.split(RegExp(r'[+-]')).first;
      final parts = core.split('.').take(3).map((e) => int.tryParse(e) ?? 0).toList();
      while (parts.length < 3) { parts.add(0); }
      return parts;
    }
    final a = parse(candidate), b = parse(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}
