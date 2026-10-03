import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screen_preferences.dart';

final screenRouteObserver = RouteObserver<ModalRoute<dynamic>>();

List<DeviceOrientation> preferredOrientations(ScreenOrientation value) => switch (value) {
  ScreenOrientation.automatic => const [],
  ScreenOrientation.portrait => const [DeviceOrientation.portraitUp],
  ScreenOrientation.landscape => const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
};

// Tokens distinguish simultaneously mounted routes; a hidden route releases its token.
class ScreenAwakePolicy {
  final Set<Object> _visibleActivities = {};
  bool foreground = true;
  bool enabled = true;
  bool get shouldKeepAwake => foreground && enabled && _visibleActivities.isNotEmpty;
  void activity(Object token, bool active) {
    if (active) { _visibleActivities.add(token); } else { _visibleActivities.remove(token); }
  }
}

class ScreenRuntime extends StatefulWidget {
  const ScreenRuntime({super.key, required this.preferences, required this.child, this.setKeepAwake, this.applyOrientation});
  final ScreenPreferencesController preferences;
  final Widget child;
  final Future<void> Function(bool)? setKeepAwake;
  final Future<void> Function(List<DeviceOrientation>)? applyOrientation;
  @override
  State<ScreenRuntime> createState() => _ScreenRuntimeState();
}

class _ScreenRuntimeState extends State<ScreenRuntime> with WidgetsBindingObserver {
  final policy = ScreenAwakePolicy();
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;
  String? _applied;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.preferences.addListener(_apply);
    policy.foreground = WidgetsBinding.instance.lifecycleState == null || WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _apply();
  }

  void activity(Object token, bool active) { policy.activity(token, active); _apply(); }

  void _apply({bool force = false}) {
    if (_disposed) { return; }
    final value = widget.preferences.value;
    policy.enabled = value.keepAwake;
    final signature = '${value.orientation.name}:${policy.shouldKeepAwake}';
    if (!force && signature == _applied) { return; }
    _applied = signature;
    _queue = _queue.then((_) async {
      if (_disposed) { return; }
      try {
        final orientations = preferredOrientations(value.orientation);
        if (widget.applyOrientation != null) { await widget.applyOrientation!(orientations); }
        else { await SystemChrome.setPreferredOrientations(orientations); }
        await _setAwake(policy.shouldKeepAwake);
        if (mounted && _error != null) { setState(() => _error = null); }
      } catch (_) {
        _applied = null;
        if (mounted) { setState(() => _error = 'Skjermvalget kunne ikke brukes. Prøv igjen.'); }
      }
    });
  }

  Future<void> _setAwake(bool enabled) => widget.setKeepAwake != null
      ? widget.setKeepAwake!(enabled) : WakelockPlus.toggle(enable: enabled);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    policy.foreground = state == AppLifecycleState.resumed;
    _apply(force: true);
  }

  @override
  Widget build(BuildContext context) => _ScreenRuntimeScope(state: this, child: Stack(children: [
    widget.child,
    if (_error != null) Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(child: Material(
      borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(title: Text(_error!), trailing: IconButton(icon: const Icon(Icons.refresh),
        onPressed: () => _apply(force: true))),
    ))),
  ]));

  @override
  void dispose() {
    _disposed = true;
    widget.preferences.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_queue.then((_) => _setAwake(false)).catchError((Object _) {}));
    super.dispose();
  }
}

class _ScreenRuntimeScope extends InheritedWidget {
  const _ScreenRuntimeScope({required this.state, required super.child});
  final _ScreenRuntimeState state;
  @override
  bool updateShouldNotify(_ScreenRuntimeScope oldWidget) => oldWidget.state != state;
}

class ScreenActivity extends StatefulWidget {
  const ScreenActivity({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<ScreenActivity> createState() => _ScreenActivityState();
}

class _ScreenActivityState extends State<ScreenActivity> with RouteAware {
  _ScreenRuntimeState? _runtime;
  ModalRoute<dynamic>? _route;
  bool _visible = true;
  void _sync() => _runtime?.activity(this, widget.active && _visible);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = context.dependOnInheritedWidgetOfExactType<_ScreenRuntimeScope>()?.state;
    if (_runtime != runtime) { _runtime?.activity(this, false); _runtime = runtime; }
    final route = ModalRoute.of<dynamic>(context);
    if (_route != route) {
      screenRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) { screenRouteObserver.subscribe(this, route); }
    }
    _visible = route?.isCurrent ?? true;
    _sync();
  }
  @override
  void didUpdateWidget(covariant ScreenActivity oldWidget) { super.didUpdateWidget(oldWidget); _sync(); }
  @override
  void didPush() { _visible = true; _sync(); }
  @override
  void didPopNext() { _visible = true; _sync(); }
  @override
  void didPushNext() { _visible = false; _sync(); }
  @override
  void didPop() { _visible = false; _sync(); }
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() { screenRouteObserver.unsubscribe(this); _runtime?.activity(this, false); super.dispose(); }
}
