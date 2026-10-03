import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/storage/local_store.dart';
import '../domain/offline_area.dart';
import '../../../core/storage/offline_map_service.dart';

class OfflineMapEntry {
  const OfflineMapEntry(this.region, this.status);
  final OfflineRegion region;
  final OfflineRegionStatus? status;
  String get name => region.metadata['name']?.toString() ?? 'Kartområde ${region.id}';
  bool get ready => status?.isComplete == true;
  int get bytes => status?.completedResourceSize ?? 0;
  double get progress {
    if (ready) return 1;
    final total = status?.requiredResourceCount ?? 0;
    return total <= 0 ? 0.0 : ((status?.completedResourceCount ?? 0) / total).clamp(0.0, 1.0).toDouble();
  }
}

class OfflineMapController extends ChangeNotifier with WidgetsBindingObserver {
  OfflineMapController(this.store, {OfflineBackend? backend, this.onReady, this.onFailure, this.pollInterval = const Duration(seconds: 2)}) : backend = backend ?? NativeOfflineBackend(),
    onlyWifi = store.readBool('offline_only_wifi', fallback: true);
  final LocalStore store;
  final Duration pollInterval;
  final OfflineBackend backend;
  final Future<void> Function(String, String?)? onReady;
  final Future<void> Function(String, String?)? onFailure;
  List<OfflineMapEntry> entries = const [];
  bool loading = false;
  bool busy = false;
  bool onlyWifi;
  bool wifi = false;
  String? message;
  String? activeName;
  int? activeId;
  bool paused = false;
  bool _disposed = false;
  bool _foreground = true;
  bool _refreshing = false;
  int _generation = 0;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _network;
  final Set<int> _sessionIds = {};
  static const lightStyle = 'https://tiles.openfreemap.org/styles/liberty';
  static const darkStyle = 'https://tiles.openfreemap.org/styles/dark';

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null || WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    try {
      final connectivity = Connectivity();
      wifi = (await connectivity.checkConnectivity()).contains(ConnectivityResult.wifi);
      if (_disposed) return;
      _network = connectivity.onConnectivityChanged.listen((results) {
        wifi = results.contains(ConnectivityResult.wifi);
        if (onlyWifi && !wifi && activeId != null && !paused) unawaited(pause());
        _notify();
      }, onError: (Object _) { message = 'Nettverkstype kunne ikke kontrolleres.'; _notify(); });
    } catch (_) { message = 'Nettverkstype kunne ikke kontrolleres.'; }
    if (_disposed) return;
    await refresh();
    // Downloads interrupted by app shutdown are not silently resumed on mobile data.
    for (final entry in entries.where((e) => !e.ready)) {
      try { await backend.pause(entry.region.id); } catch (_) {}
    }
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (busy && !paused) { unawaited(refresh(quiet: true)); }
    });
  }
  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> refresh({bool quiet = false}) async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    if (!quiet) { loading = true; _notify(); }
    try {
      final regions = await backend.list();
      final rows = <OfflineMapEntry>[];
      for (final region in regions) {
        OfflineRegionStatus? status;
        try { status = await backend.status(region.id); } catch (_) {}
        rows.add(OfflineMapEntry(region, status));
      }
      if (_disposed) return;
      entries = rows;
      final active = entries.where((e) => e.region.id == activeId).firstOrNull;
      if (active?.ready == true) { _sessionIds.remove(active!.region.id); }
    } catch (_) { if (!quiet) message = 'Kunne ikke lese nedlastede kart. Prøv igjen.'; }
    finally { loading = false; _refreshing = false; _notify(); }
  }

  Future<void> setOnlyWifi(bool value) async {
    await store.writeBool('offline_only_wifi', value);
    onlyWifi = value;
    if (value && !wifi && activeId != null) await pause();
    _notify();
  }
  void _checkNetwork() {
    if (!_foreground) throw StateError('Åpne appen for å starte eller fortsette nedlasting.');
    if (onlyWifi && !wifi) throw StateError('Koble til Wi-Fi eller slå av «Kun Wi-Fi» først.');
  }

  Future<void> download(OfflineArea area, {bool bothThemes = true}) async {
    if (busy) throw StateError('En nedlasting er allerede aktiv.');
    if (!area.valid || area.estimatedTiles > OfflineArea.maxTiles) throw StateError('Området er for stort. Velg et mindre område eller lavere detaljnivå.');
    _checkNetwork();
    busy = true; paused = false; message = null; activeName = area.name; _notify();
    final generation = ++_generation;
    var downloadedSomething = false;
    try {
      for (final style in bothThemes ? [lightStyle, darkStyle] : [lightStyle]) {
        if (_disposed || generation != _generation) return;
        _checkNetwork();
        // Reuse an exact existing definition instead of plugin re-download, which deletes duplicates.
        final definition = area.definition(style);
        final existing = entries.where((e) => _same(e.region.definition, definition)).firstOrNull;
        if (existing?.ready == true) continue;
        final region = existing?.region ?? await backend.create(definition, {'name': area.name,
          'tripId': area.tripId, 'type': 'govia-area', 'theme': style == darkStyle ? 'dark' : 'light',
          'createdAt': DateTime.now().toUtc().toIso8601String()});
        if (_disposed || generation != _generation) { await backend.pause(region.id); return; }
        downloadedSomething = true;
        activeId = region.id; _sessionIds.add(region.id); _notify();
        if (existing != null) await backend.resume(region.id);
        await _wait(region.id, generation);
        if (_disposed || generation != _generation) return;
      }
      message = 'Kartnedlastingen er ferdig. Området er tilgjengelig offline.';
      if (downloadedSomething) { try { await onReady?.call(area.name, area.tripId); } catch (_) {} }
    } catch (error) {
      final id = activeId;
      if (id != null) { try { await backend.pause(id); } catch (_) {} }
      message = 'Nedlasting stoppet: $error';
      if (!_disposed && generation == _generation) { try { await onFailure?.call(area.name, area.tripId); } catch (_) {} }
      rethrow;
    }
    finally {
      if (generation == _generation) { busy = false; activeId = null; activeName = null; }
      await refresh(); _notify();
    }
  }

  bool _same(OfflineRegionDefinition a, OfflineRegionDefinition b) =>
    a.mapStyleUrl == b.mapStyleUrl && a.includeIdeographs == b.includeIdeographs && a.minZoom == b.minZoom && a.maxZoom == b.maxZoom &&
    a.bounds.southwest.latitude == b.bounds.southwest.latitude && a.bounds.southwest.longitude == b.bounds.southwest.longitude &&
    a.bounds.northeast.latitude == b.bounds.northeast.latitude && a.bounds.northeast.longitude == b.bounds.northeast.longitude;

  Future<void> _wait(int id, int generation) async {
    var idle = 0;
    var lastCount = -1;
    while (!_disposed && generation == _generation) {
      if ((!_foreground || (onlyWifi && !wifi)) && !paused) await pause();
      if (!paused) {
        final status = await backend.status(id);
        await refresh(quiet: true);
        if (status.isComplete) return;
        idle = status.completedResourceCount == lastCount ? idle + 1 : 0;
        lastCount = status.completedResourceCount;
        if (idle >= 90) throw StateError('Nedlastingen står stille. Den delvise pakken er beholdt; fortsett når nettet fungerer.');
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> pause() async {
    final id = activeId;
    if (id == null) return;
    try { await backend.pause(id); paused = true; _notify(); }
    catch (_) { message = 'Kunne ikke pause nedlastingen.'; _notify(); }
  }
  Future<void> continueDownload(OfflineMapEntry entry, {bool notify = true}) async {
    _checkNetwork();
    if (busy) {
      if (activeId != entry.region.id) throw StateError('En annen nedlasting er aktiv.');
      await backend.resume(entry.region.id); paused = false; _notify(); return;
    }
    busy = true; paused = false; message = null; activeId = entry.region.id; activeName = entry.name; _sessionIds.add(entry.region.id);
    final generation = ++_generation; _notify();
    try {
      await backend.resume(entry.region.id); await _wait(entry.region.id, generation);
      if (!_disposed && generation == _generation && notify) {
        try { await onReady?.call(entry.name, entry.region.metadata['tripId']?.toString()); } catch (_) {}
      }
    } catch (_) {
      try { await backend.pause(entry.region.id); } catch (_) {}
      if (!_disposed && generation == _generation) { try { await onFailure?.call(entry.name, entry.region.metadata['tripId']?.toString()); } catch (_) {} }
      rethrow;
    }
    finally {
      if (generation == _generation) { busy = false; activeId = null; activeName = null; }
      await refresh(); _notify();
    }
  }
  Future<void> update(OfflineMapEntry entry) async {
    if (busy) throw StateError('Vent til den aktive nedlastingen er ferdig.');
    _checkNetwork();
    busy = true; paused = true; message = null; activeId = entry.region.id; activeName = entry.name;
    final generation = ++_generation; _notify();
    try {
      await backend.invalidate(entry.region.id);
      if (_disposed || generation != _generation) return;
      _checkNetwork();
      _sessionIds.add(entry.region.id);
      await backend.resume(entry.region.id); paused = false; _notify();
      await _wait(entry.region.id, generation);
      if (!_disposed && generation == _generation) {
        message = 'Kartpakken er kontrollert for tilgjengelige ressurser. Nye kartdata hentes ved behov.';
      }
    } catch (_) {
      try { await backend.pause(entry.region.id); } catch (_) {}
      if (!_disposed && generation == _generation) { try { await onFailure?.call(entry.name, entry.region.metadata['tripId']?.toString()); } catch (_) {} }
      rethrow;
    }
    finally {
      if (generation == _generation) { busy = false; activeId = null; activeName = null; }
      await refresh(); _notify();
    }
  }
  Future<void> delete(OfflineMapEntry entry) async {
    if (busy) throw StateError('Stopp nedlastingen før du sletter kart.');
    await backend.delete(entry.region.id); _sessionIds.remove(entry.region.id); await refresh();
  }
  Future<void> stop() async {
    final id = activeId;
    _generation++;
    if (id != null) await backend.pause(id);
    busy = false; activeId = null; activeName = null; paused = false;
    message = 'Nedlastingen er stoppet. Delvis kart er beholdt.'; _notify();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed && activeId != null && !paused) { unawaited(pause()); }
    if (state == AppLifecycleState.resumed) { unawaited(refresh(quiet: true)); }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true; _generation++; _timer?.cancel(); unawaited(_network?.cancel());
    for (final id in _sessionIds) { unawaited(backend.pause(id).catchError((Object _) {})); }
    super.dispose();
  }
}

class OfflineMapScope extends InheritedNotifier<OfflineMapController> {
  const OfflineMapScope({super.key, required OfflineMapController controller, required super.child}) : super(notifier: controller);
  static OfflineMapController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<OfflineMapScope>()!.notifier!;
}
