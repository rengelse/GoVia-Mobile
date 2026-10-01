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

    workflow = (ROOT / '.github/workflows/android-release.yml').read_text(encoding='utf-8')
    ok &= check('connected Android test XML results' in workflow and "find app/build/outputs/androidTest-results/connected" in workflow,
                'CI prints exact connected-test XML on Android instrumentation failure')
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
