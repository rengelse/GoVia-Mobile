import 'package:flutter/widgets.dart';
import '../storage/local_store.dart';

enum ScreenOrientation { automatic, portrait, landscape }
enum PhoneMapMode { perspective, northUp, overview }

class ScreenPreferences {
  const ScreenPreferences({this.orientation = ScreenOrientation.automatic,
    this.keepAwake = true, this.mapMode = PhoneMapMode.perspective,
    this.autoZoom = true, this.showSpeedLimit = true, this.showSpeed = true, this.warnOverspeed = false});
  final ScreenOrientation orientation;
  final bool keepAwake;
  final PhoneMapMode mapMode;
  final bool autoZoom;
  final bool showSpeedLimit;
  final bool showSpeed;
  final bool warnOverspeed;

  ScreenPreferences copyWith({ScreenOrientation? orientation, bool? keepAwake,
    PhoneMapMode? mapMode, bool? autoZoom, bool? showSpeedLimit, bool? showSpeed, bool? warnOverspeed}) => ScreenPreferences(
      orientation: orientation ?? this.orientation, keepAwake: keepAwake ?? this.keepAwake,
      mapMode: mapMode ?? this.mapMode, autoZoom: autoZoom ?? this.autoZoom,
      showSpeedLimit: showSpeedLimit ?? this.showSpeedLimit, showSpeed: showSpeed ?? this.showSpeed, warnOverspeed: warnOverspeed ?? this.warnOverspeed);

  Map<String, dynamic> toJson() => {'orientation': orientation.name, 'keepAwake': keepAwake,
    'mapMode': mapMode.name, 'autoZoom': autoZoom, 'showSpeedLimit': showSpeedLimit, 'showSpeed': showSpeed, 'warnOverspeed': warnOverspeed};

  factory ScreenPreferences.fromJson(Map<String, dynamic>? json) {
    bool flag(String key) => json?[key] is bool ? json![key] as bool : true;
    return ScreenPreferences(
      orientation: ScreenOrientation.values.where((v) => v.name == json?['orientation']).firstOrNull ?? ScreenOrientation.automatic,
      mapMode: PhoneMapMode.values.where((v) => v.name == json?['mapMode']).firstOrNull ?? PhoneMapMode.perspective,
      keepAwake: flag('keepAwake'), autoZoom: flag('autoZoom'),
      showSpeedLimit: flag('showSpeedLimit'), showSpeed: flag('showSpeed'), warnOverspeed: json?['warnOverspeed'] == true);
  }
}

class ScreenPreferencesController extends ChangeNotifier {
  ScreenPreferencesController(this.store) : value = ScreenPreferences.fromJson(store.readJson(storageKey));
  static const storageKey = 'phone_screen_preferences';
  final LocalStore store;
  ScreenPreferences value;
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;

  Future<void> save(ScreenPreferences next) {
    final operation = _writes.then((_) async {
      await store.writeJson(storageKey, next.toJson());
      if (_disposed) { return; }
      value = next;
      notifyListeners();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  @override
  void dispose() { _disposed = true; super.dispose(); }
}

class ScreenPreferencesScope extends InheritedNotifier<ScreenPreferencesController> {
  const ScreenPreferencesScope({super.key, required ScreenPreferencesController controller, required super.child}) : super(notifier: controller);
  static ScreenPreferencesController? maybeOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<ScreenPreferencesScope>()?.notifier;
}
