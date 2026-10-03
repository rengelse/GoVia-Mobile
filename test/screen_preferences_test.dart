import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:govia_mobile/core/display/screen_preferences.dart';
import 'package:govia_mobile/core/display/screen_runtime.dart';
import 'package:govia_mobile/core/display/phone_map_zoom.dart';
import 'package:govia_mobile/core/storage/local_store.dart';
import 'package:govia_mobile/features/profile/presentation/screen_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ListView creates children lazily. Scroll first, then settle layout before hit testing.
  Future<void> revealSetting(WidgetTester tester, Finder setting) async {
    await tester.scrollUntilVisible(setting, 120,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final tile = find.ancestor(of: setting, matching: find.byType(SwitchListTile));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(setting.hitTestable(), findsOneWidget);
  }


  test('preferences round-trip all values and reject malformed stored options', () {
    const value = ScreenPreferences(orientation: ScreenOrientation.landscape, keepAwake: false,
      mapMode: PhoneMapMode.overview, autoZoom: false, showSpeed: false, showSpeedLimit: false, warnOverspeed: true);
    expect(ScreenPreferences.fromJson(value.toJson()).toJson(), value.toJson());
    final invalid = ScreenPreferences.fromJson({'orientation': 'invalid', 'mapMode': 2, 'autoZoom': 'false'});
    expect(invalid.orientation, ScreenOrientation.automatic);
    expect(invalid.mapMode, PhoneMapMode.perspective);
    expect(invalid.autoZoom, isTrue);
    expect(invalid.warnOverspeed, isFalse);
    expect(preferredOrientations(ScreenOrientation.automatic), isEmpty);
    expect(preferredOrientations(ScreenOrientation.landscape),
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  });

  test('screen activity policy releases on hide, background and disabled preference', () {
    final policy = ScreenAwakePolicy();
    final a = Object(); final b = Object();
    expect(policy.shouldKeepAwake, isFalse);
    policy.activity(a, true); policy.activity(b, true); policy.activity(a, false);
    expect(policy.shouldKeepAwake, isTrue);
    policy.foreground = false;
    expect(policy.shouldKeepAwake, isFalse);
    policy.foreground = true; policy.enabled = false;
    expect(policy.shouldKeepAwake, isFalse);
    policy.enabled = true; policy.activity(b, false);
    expect(policy.shouldKeepAwake, isFalse);
  });

  test('manual zoom survives speed and maneuver changes; automatic zoom adapts', () {
    expect(phoneMapZoom(automatic: false, currentZoom: 12.7, speedMetersPerSecond: 30, maneuverDistance: 20), 12.7);
    expect(phoneMapZoom(automatic: true, currentZoom: 12.7, speedMetersPerSecond: 30), 14.3);
    expect(phoneMapZoom(automatic: true, currentZoom: 12.7, speedMetersPerSecond: 30, maneuverDistance: 20), 17.2);
    expect(phoneSpeedLabel(-1), 'Ukjent');
    expect(phoneSpeedLabel(double.nan), 'Ukjent');
    expect(phoneSpeedLabel(10), '36 km/t');
    expect(phoneSpeedLabel(10, imperial: true), '22 mph');
  });

  test('settings persist through recreation and concurrent saves finish in order', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    final controller = ScreenPreferencesController(store);
    final a = controller.save(const ScreenPreferences(showSpeed: false));
    final b = controller.save(const ScreenPreferences(showSpeed: false, autoZoom: false, warnOverspeed: true));
    await Future.wait([a, b]);
    final restored = ScreenPreferencesController(store);
    expect(restored.value.showSpeed, isFalse);
    expect(restored.value.autoZoom, isFalse);
    expect(restored.value.warnOverspeed, isTrue);
    controller.dispose(); restored.dispose();
  });

  testWidgets('settings switch persists without changing independent display choices', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ScreenPreferencesController(await LocalStore.create());
    await tester.pumpWidget(ScreenPreferencesScope(controller: controller,
      child: const MaterialApp(home: ScreenSettingsScreen())));
    final speed = find.text('Egen hastighet');
    await revealSetting(tester, speed);
    await tester.tap(speed);
    await tester.pumpAndSettle();
    expect(controller.value.showSpeed, isFalse);
    expect(controller.value.showSpeedLimit, isTrue);
    expect(controller.value.autoZoom, isTrue);
    await tester.pumpWidget(const SizedBox.shrink()); controller.dispose();
  });

  testWidgets('warning can be enabled and hidden speed disables its switch without losing preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ScreenPreferencesController(await LocalStore.create());
    await tester.pumpWidget(ScreenPreferencesScope(controller: controller,
      child: const MaterialApp(home: ScreenSettingsScreen())));
    final warning = find.text('Varsel ved overskridelse');
    await revealSetting(tester, warning); await tester.tap(warning); await tester.pumpAndSettle();
    expect(controller.value.warnOverspeed, isTrue);
    final speed = find.text('Egen hastighet');
    await revealSetting(tester, speed); await tester.tap(speed); await tester.pumpAndSettle();
    await revealSetting(tester, warning);
    final tile = tester.widget<SwitchListTile>(find.ancestor(of: warning, matching: find.byType(SwitchListTile)));
    expect(tile.onChanged, isNull);
    expect(controller.value.warnOverspeed, isTrue);
    final restored = ScreenPreferencesController(controller.store);
    expect(restored.value.warnOverspeed, isTrue); restored.dispose();
    await tester.pumpWidget(const SizedBox.shrink()); controller.dispose();
  });

  testWidgets('runtime releases awake when another route covers navigation and restores on back', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ScreenPreferencesController(await LocalStore.create());
    final calls = <bool>[];
    await tester.pumpWidget(MaterialApp(navigatorObservers: [screenRouteObserver],
      builder: (_, child) => ScreenRuntime(preferences: controller, child: child!,
        setKeepAwake: (value) async { calls.add(value); }, applyOrientation: (_) async {}),
      home: ScreenActivity(active: true, child: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(), body: const Text('Annen side')))),
        child: const Text('Åpne')))))));
    await tester.pumpAndSettle();
    expect(calls.last, isTrue);
    await tester.tap(find.text('Åpne')); await tester.pumpAndSettle();
    expect(calls.last, isFalse);
    await tester.pageBack(); await tester.pumpAndSettle();
    expect(calls.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(calls.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls.last, isTrue);
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle();
    expect(calls.last, isFalse);
    controller.dispose();
  });
}
