import 'dart:io';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

abstract class OfflineBackend {
  Future<List<OfflineRegion>> list();
  Future<OfflineRegionStatus> status(int id);
  Future<OfflineRegion> create(OfflineRegionDefinition definition, Map<String, dynamic> metadata);
  Future<void> pause(int id);
  Future<void> resume(int id);
  Future<void> invalidate(int id);
  Future<void> delete(int id);
}

class NativeOfflineBackend implements OfflineBackend {
  static const _channel = MethodChannel('no.govia.mobile/offline');
  @override
  Future<List<OfflineRegion>> list() => getListOfRegions();
  @override
  Future<OfflineRegionStatus> status(int id) => getOfflineRegionStatus(id);
  @override
  Future<OfflineRegion> create(OfflineRegionDefinition definition, Map<String, dynamic> metadata) => downloadOfflineRegion(definition, metadata: metadata);
  @override
  Future<void> pause(int id) => pauseOfflineRegionDownload(id);
  @override
  Future<void> resume(int id) async {
    if (Platform.isAndroid) { await _channel.invokeMethod<void>('resume', {'id': id}); }
    else { await resumeOfflineRegionDownload(id); }
  }
  @override
  Future<void> invalidate(int id) async {
    if (!Platform.isAndroid) throw UnsupportedError('Kartoppdatering er foreløpig tilgjengelig på Android.');
    await _channel.invokeMethod<void>('invalidate', {'id': id});
  }
  @override
  Future<void> delete(int id) async {
    await deleteOfflineRegion(id);
    if (Platform.isAndroid) { await _channel.invokeMethod<void>('release', {'id': id}); }
    await clearAmbientCache();
  }
}
