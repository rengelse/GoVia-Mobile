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

    ci = subprocess.run([sys.executable, str(ROOT / 'tool/ci_contract_verifier.py')], cwd=ROOT)
    ok &= ci.returncode == 0
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
