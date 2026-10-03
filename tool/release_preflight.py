#!/usr/bin/env python3
from pathlib import Path
import py_compile
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def check(condition: bool, label: str) -> bool:
    print(('OK   ' if condition else 'FAIL ') + label)
    return bool(condition)


def check_dart_imports() -> bool:
    issues = []
    dart_files = list((ROOT / 'lib').rglob('*.dart')) + list((ROOT / 'test').rglob('*.dart'))
    pattern = re.compile(r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", re.M)
    for path in dart_files:
        text = path.read_text(encoding='utf-8')
        for match in pattern.finditer(text):
            uri = match.group(1)
            if uri.startswith('dart:'):
                continue
            if uri.startswith('package:'):
                if not uri.startswith('package:govia_mobile/'):
                    continue
                target = ROOT / 'lib' / uri[len('package:govia_mobile/'):]
            else:
                target = (path.parent / uri).resolve()
            if not target.exists():
                issues.append(f'{path.relative_to(ROOT)} -> {uri}')
    for issue in issues:
        print('FAIL missing Dart target: ' + issue)
    if not issues:
        print('OK   all local Dart imports/exports resolve')
    return not issues


def check_xml() -> bool:
    issues = []
    for path in (ROOT / 'android/app/src').rglob('*.xml'):
        try:
            ET.parse(path)
        except Exception as exc:
            issues.append(f'{path.relative_to(ROOT)}: {exc}')
    for issue in issues:
        print('FAIL invalid Android XML: ' + issue)
    if not issues:
        print('OK   all Android XML files parse')
    return not issues


def check_python() -> bool:
    issues = []
    for path in (ROOT / 'tool').glob('*.py'):
        try:
            py_compile.compile(str(path), doraise=True)
        except Exception as exc:
            issues.append(f'{path.name}: {exc}')
    for issue in issues:
        print('FAIL Python syntax: ' + issue)
    if not issues:
        print('OK   all Python release tools compile')
    return not issues


def check_source_contracts() -> bool:
    ok = True
    cockpit = ROOT / 'test/android_auto_cockpit_layout_test.dart'
    text = cockpit.read_text(encoding='utf-8') if cockpit.exists() else ''
    ok &= check(
        'annotationsForStep(stage.speedLimitSections' not in text,
        'Android Auto speed-limit test does not use formatter-sensitive substring',
    )
    ok &= check(
        r'annotationsForStep\s*\(\s*stage\.speedLimitSections\s*,' in text,
        'Android Auto speed-limit source contract uses whitespace-tolerant regex',
    )

    runtime = (ROOT / 'android/app/src/main/kotlin/no/govia/mobile/car/FerrostarNavigationRuntime.kt').read_text(encoding='utf-8')
    ok &= check(
        'RouteDeviationTracking.StaticThreshold(25u, 55.0)' in runtime,
        'Ferrostar deviation detection accepts all GOOD GPS fixes (<=25 m)',
    )
    ok &= check(
        'RouteDeviationTracking.StaticThreshold(5u, 55.0)' not in runtime,
        'obsolete 5 m deviation accuracy gate is absent',
    )
    ok &= check(
        'DeviationKind.CompletelyOffRoute' in runtime and 'else -> CarOffRouteState.SUSPECT' in runtime,
        'Ferrostar deviation kind distinguishes complete off-route from non-rerouting deviation',
    )
    ok &= check(
        'rerouteRequired = offRouteState == CarOffRouteState.OFF_ROUTE' in runtime,
        'reroute is requested only for complete off-route state',
    )
    ok &= check(
        'contains("NoDeviation"' not in runtime,
        'fragile RouteDeviation string parsing is absent',
    )

    service = (ROOT / 'android/app/src/main/kotlin/no/govia/mobile/car/GoViaNavigationService.kt').read_text(encoding='utf-8')
    ok &= check(
        'session?.offRouteState == CarOffRouteState.OFF_ROUTE' in service and 'return Location(raw)' in service,
        'Android Auto/phone display uses raw GPS location while off-route',
    )

    instrumented = (ROOT / 'android/app/src/androidTest/kotlin/no/govia/mobile/car/FerrostarProductionRuntimeTest.kt').read_text(encoding='utf-8')
    ok &= check('goodAccuracyDeviationTriggersRerouteBeforeArrival' in instrumented,
                'instrumented test covers good-accuracy off-route detection')
    ok &= check('degradedAccuracyDoesNotCreateFalseOffRouteSignal' in instrumented,
                'instrumented test covers degraded-accuracy suppression')
    ok &= check('lat = anchor.lat + 0.0020' in instrumented,
                'instrumented deviation trace uses lateral offset instead of far-ahead endpoint snapping')

    app_state = (ROOT / 'lib/app/app_state.dart').read_text(encoding='utf-8')
    shell_screen = (ROOT / 'lib/app/shell_screen.dart').read_text(encoding='utf-8')
    profile_screen = (ROOT / 'lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8')
    nav_screen = (ROOT / 'lib/features/navigation/presentation/navigation_screen.dart').read_text(encoding='utf-8')
    voice_localizer = (ROOT / 'lib/features/navigation/domain/navigation_voice_localizer.dart').read_text(encoding='utf-8')
    car_voice = (ROOT / 'android/app/src/main/kotlin/no/govia/mobile/car/NavigationVoiceLocalizer.kt').read_text(encoding='utf-8')
    simulator = (ROOT / 'lib/dev/navigation_simulator/simulator_models.dart').read_text(encoding='utf-8')
    simulator_screen = (ROOT / 'lib/dev/navigation_simulator/navigation_simulator_screen.dart').read_text(encoding='utf-8')
    manifest = (ROOT / 'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
    ok &= check("'navigationLanguage': navigationLanguage" in app_state and "navigation_language" in app_state,
                'navigation language is persisted and synchronized to Android Auto')
    ok &= check("'Navigasjonsspråk'" in profile_screen and "'auto': 'Automatisk'" in profile_screen and "'en': 'English'" in profile_screen,
                'profile exposes automatic/Norwegian/English navigation language choices')
    ok &= check('NavigationVoiceLocalizer(_navigationLanguage).instruction' in nav_screen and '_runtimeState?.spokenInstructionText' not in nav_screen[nav_screen.find('Future<void> _announceIfNeeded'):nav_screen.find('String _distanceLabel')],
                'phone TTS localizes semantic maneuvers instead of speaking provider text')
    ok &= check('object NavigationVoiceLocalizer' in car_voice and 'NavigationVoiceLocalizer.instruction' in service,
                'Android Auto TTS uses the same semantic localization policy')
    ok &= check('android.intent.action.TTS_SERVICE' in manifest,
                'Android manifest exposes TTS service discovery')
    ok &= check('displayInstruction(maneuver)' in nav_screen and '_runtimeState!.nextManeuver!.instruction' not in nav_screen,
                'phone navigation cards localize semantic maneuver text')
    ok &= check('NavigationVoiceLocalizer.displayInstruction(navigationLanguage, maneuver)' in service,
                'Android Auto navigation cards localize semantic maneuver text')
    ok &= check(all(value in simulator for value in ["id: 'country-road'", "id: 'motorway-exit'", "id: 'roundabout'", "id: 'intersection'", "id: 'speed-limits'", "id: 'reroute'", "id: 'arrival'"]),
                'navigation simulator contains all acceptance scenarios')
    ok &= check('startPathIndex: startPathIndex' in simulator and 'endPathIndex: endPathIndex' in simulator,
                'simulator fallback speed limits carry Ferrostar path indexes')
    ok &= check('_densifyGeometry(points)' in simulator and 'shapeIndex: shapeIndex' in simulator and '_anchorSimulatorManeuvers' in simulator,
                'simulator routes have dense geometry and explicit Ferrostar maneuver anchors')
    ok &= check('return scenario;' in simulator_screen and 'Veinett-rute utilgjengelig' in simulator_screen,
                'simulator has deterministic built-in fallback when live routing is unavailable')
    ok &= check("Navigator.pop(dialogContext, 'complete')" in nav_screen and '_handleArrival()' in nav_screen,
                'navigation has explicit stop/complete and arrival completion flows')

    notification_model = (ROOT / 'lib/features/notifications/domain/govia_notification.dart').read_text(encoding='utf-8')
    notification_repository = (ROOT / 'lib/features/notifications/data/notification_repository.dart').read_text(encoding='utf-8')
    notification_screen = (ROOT / 'lib/features/notifications/presentation/notifications_screen.dart').read_text(encoding='utf-8')
    home_map_preferences = (ROOT / 'lib/features/home/domain/map_home_preferences.dart').read_text(encoding='utf-8')
    home_screen = (ROOT / 'lib/features/home/presentation/home_screen.dart').read_text(encoding='utf-8')
    offline_screen = (ROOT / 'lib/features/offline/presentation/offline_screen.dart').read_text(encoding='utf-8')
    ok &= check('class GoViaNotification' in notification_model and 'readAt' in notification_model and 'GoViaNotificationTargetType' in notification_model,
                'notification center uses typed read-state and action-target model')
    ok &= check("static const _storageKey = 'notification_center_v1'" in notification_repository and 'Future<void> save' in notification_repository,
                'notification inbox is persisted through a dedicated repository')
    ok &= check('state.notifications' in notification_screen and 'markAllNotificationsRead' in notification_screen and 'archiveNotification' in notification_screen,
                'notification screen renders live inbox state with read/archive actions')
    ok &= check('Marius ble med på turen.' not in notification_screen and 'Økende vind etter kl. 17.' not in notification_screen,
                'legacy notification dummy feed is absent')
    ok &= check('unreadNotificationCount' in shell_screen and "badgeCount: unreadCount" in shell_screen,
                'Shell exposes unread notification badge')
    ok &= check("label: 'Turer'" in shell_screen and "label: 'Kart'" in shell_screen and "label: 'Varsler'" in shell_screen and "label: 'Profil'" in shell_screen,
                'shell uses locked Turer/Kart/Varsler/Profil navigation')
    ok &= check("https://tiles.openfreemap.org/styles/dark" in home_map_preferences and "Planlegg tur" in home_screen,
                'map home uses full-screen dark MapLibre layout with primary trip CTA')
    ok &= check('TripDiscoveryCarousel' in home_screen and 'state.publishedRoutes' in home_screen and 'PublishedRoute' in home_screen,
                'map home trip carousel is data-driven from published GoVia routes')
    ok &= check('GoVia Premium' not in home_screen and 'Oppdag nye eventyr' not in home_screen,
                'legacy promotional banner is absent from map home')
    ok &= check("id: 'desktop-handoff-" in app_state and "id: 'route-updated-" in app_state and "id: 'trip-completed-" in app_state,
                'existing trip lifecycle events feed the notification inbox')
    ok &= check("id: 'offline-ready-" in offline_screen and "id: 'offline-failed-" in offline_screen,
                'offline download results feed the same notification inbox')

    cloud_mapper = (ROOT / 'lib/features/notifications/data/cloud_notification_mapper.dart').read_text(encoding='utf-8')
    auth_service = (ROOT / 'lib/features/auth/auth_service.dart').read_text(encoding='utf-8')
    weather_parser = (ROOT / 'lib/features/weather/data/trip_weather_parser.dart').read_text(encoding='utf-8')
    weather_screen = (ROOT / 'lib/features/weather/presentation/weather_screen.dart').read_text(encoding='utf-8')
    ok &= check("from('trip_notifications')" in auth_service and "contains('recipients', [uid])" in auth_service,
                'mobile reads the existing shared trip_notifications stream for the signed-in recipient')
    ok &= check("actorId == currentUserId" in cloud_mapper and "actor_id == null" in cloud_mapper,
                'cloud trip notifications suppress self-actions while allowing system events')
    ok &= check('PostgresChangeEvent.insert' in auth_service and 'PostgresChangeEvent.update' in auth_service,
                'trip notifications refresh in realtime while the mobile session is active')
    ok &= check("api.postJson('/api/v1/weather/route'" in app_state and "'points': points" in app_state and "'days': TripWeatherParser.daysToRequest" in app_state,
                'mobile route weather reuses the existing GoVia weather API contract')
    ok &= check('offset >= 0 && offset <= 8' in weather_parser and 'Værprognose er ikke tilgjengelig ennå' in app_state,
                'trip weather does not fabricate forecasts outside the nine-day provider window')
    ok &= check('weather-alert-' in app_state and "metadata: {'source': 'route_weather'" in app_state,
                'material route-weather conditions feed the same notification inbox with deterministic dedupe ids')
    ok &= check('refreshTripWeather' in weather_screen and 'Produksjonsdata hentes fra /api/v1/weather/route' not in weather_screen,
                'Weather screen is operational instead of a route-weather placeholder')
    ok &= check('api.met.no' not in app_state and 'api.met.no' not in weather_screen,
                'mobile never bypasses GoVia API to call the weather provider directly')

    acceptance_gate = (ROOT / 'tool/navigation_acceptance_gate.py').read_text(encoding='utf-8')
    ok &= check("print(f'COMMAND: {printable}'" in acceptance_gate and "stderr=subprocess.STDOUT" in acceptance_gate and
                "print(f'RESULT: {status} (exit code {completed.returncode})'" in acceptance_gate and "flush=True" in acceptance_gate,
                'navigation acceptance gate emits deterministic command/output/exit-code diagnostics')

    workflow = (ROOT / '.github/workflows/android-release.yml').read_text(encoding='utf-8')
    ok &= check('Dump connected Android test diagnostics' in workflow and 'if: failure()' in workflow and
                "find app/build/outputs/androidTest-results/connected" in workflow,
                'CI prints exact connected-test XML from a dedicated post-failure step')
    ok &= check('set +e' not in workflow and 'status=$?' not in workflow and 'if [ "$status" -ne 0 ]; then' not in workflow,
                'emulator-runner script avoids non-persistent multiline shell state')
    return ok


def main() -> int:
    ok = True
    ok &= check((ROOT / 'android/settings.gradle').exists() and (ROOT / 'android/app/build.gradle').exists(),
                'Android Gradle root and app module exist')
    ok &= check_dart_imports()
    ok &= check_xml()
    ok &= check_python()

    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    readme = (ROOT / 'README.md').read_text(encoding='utf-8')
    release = (ROOT / 'RELEASE.md').read_text(encoding='utf-8')
    match = re.search(r'^version:\s*([^\s]+)', pubspec, re.M)
    version = match.group(1) if match else ''
    ok &= check(bool(version) and readme.startswith(f'# GoVia Mobile v{version}') and release.startswith(f'# GoVia Mobile v{version}'),
                'pubspec/README/RELEASE version markers are synchronized')

    ok &= check(not (ROOT / 'test/fixtures/navigation_core_v2_golden.csv').exists(),
                'retired NavigationCoreV2 fixture is absent')
    ok &= check(not (ROOT / 'android/ferrostar-poc').exists(),
                'retired Ferrostar PoC module is absent')
    ok &= check_source_contracts()

    ci = subprocess.run([sys.executable, str(ROOT / 'tool/ci_contract_verifier.py')], cwd=ROOT)
    ok &= ci.returncode == 0
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
