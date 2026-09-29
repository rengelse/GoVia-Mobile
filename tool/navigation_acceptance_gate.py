#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    ROOT / 'test/navigation_session_test.dart',
    ROOT / 'test/navigation_acceptance_hardening_test.dart',
    ROOT / 'test/navigation_golden_trace_test.dart',
    ROOT / 'test/navigation_bridge_roundtrip_test.dart',
    ROOT / 'test/navigation_geometry_acceptance_test.dart',
    ROOT / 'test/fixtures/navigation_core_v2_golden.csv',
    ROOT / 'android/app/src/test/kotlin/no/govia/mobile/car/NavigationCoreV2Test.kt',
    ROOT / 'docs/NAVIGATION-CORE-V2-ACCEPTANCE.md',
    ROOT / 'tool/navigation_core_kotlin_smoke.sh',
    ROOT / 'tool/navigation_core_kotlin_smoke.kt',
]
FORBIDDEN = [
    ROOT / 'lib/features/navigation/domain/navigation_engine.dart',
    ROOT / 'test/navigation_engine_test.dart',
]


def run(label: str, cmd: list[str], cwd: Path = ROOT) -> bool:
    print(f'\n== {label} ==')
    result = subprocess.run(cmd, cwd=cwd)
    return result.returncode == 0


def main() -> int:
    ok = True
    for path in REQUIRED:
        exists = path.exists()
        print(('OK  ' if exists else 'FAIL') + f' required: {path.relative_to(ROOT)}')
        ok &= exists
    for path in FORBIDDEN:
        absent = not path.exists()
        print(('OK  ' if absent else 'FAIL') + f' forbidden absent: {path.relative_to(ROOT)}')
        ok &= absent

    ok &= run('release contract verifier', [sys.executable, 'tool/verify_mobile.py'])
    if shutil.which('kotlinc'):
        ok &= run('standalone Kotlin core smoke', ['bash', 'tool/navigation_core_kotlin_smoke.sh'])
    else:
        print('\nSKIP: standalone kotlinc is unavailable; Gradle native tests remain mandatory below.')

    flutter = shutil.which('flutter')
    if not flutter:
        print('\nBLOCKED: Flutter SDK is not available; analyze/test gate cannot be completed locally.')
        return 2

    ok &= run('flutter analyze', [flutter, 'analyze'])
    ok &= run('flutter test', [flutter, 'test'])

    gradlew = ROOT / 'android/gradlew'
    if not gradlew.exists():
        print('\nBLOCKED: android/gradlew is absent. CI generates it before native tests.')
        return 2
    ok &= run('native unit tests', [str(gradlew), 'testDebugUnitTest', '--no-daemon'], ROOT / 'android')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
