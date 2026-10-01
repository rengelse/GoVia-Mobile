#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/android-release.yml'


def check(condition: bool, label: str) -> bool:
    print(('OK   ' if condition else 'FAIL ') + label)
    return bool(condition)


def main() -> int:
    text = WORKFLOW.read_text(encoding='utf-8')
    ok = True

    ok &= check('Enable KVM for Android emulator' in text and 'test -e /dev/kvm' in text,
                'KVM is explicitly enabled and verified')
    ok &= check(bool(re.search(r'reactivecircus/android-emulator-runner@[0-9a-f]{40}', text)),
                'emulator runner is pinned to an immutable commit')
    ok &= check('working-directory: ./android' in text,
                'emulator action runs scripts from Android Gradle root')
    ok &= check('\n            cd android\n' not in text and '\n            cd android ' not in text,
                'emulator script does not rely on non-persistent cd state')
    ok &= check('gradle :app:connectedDebugAndroidTest ' in text,
                'instrumented test command targets the app Gradle project')
    ok &= check('gradle :app:connectedDebugAndroidTest \\\n' not in text,
                'instrumented Gradle command is a single shell command')
    ok &= check('gradle -p android :app:assembleDebug :app:assembleDebugAndroidTest' in text,
                'APK and androidTest packages are built before emulator launch')
    ok &= check('emulator-${EMULATOR_PORT}' in text,
                'ADB diagnostics use the action-provided emulator port')
    ok &= check('api-level: 35' in text and 'target: default' in text and 'arch: x86_64' in text,
                'emulator image contract is explicit')
    ok &= check('emulator-boot-timeout: 900' in text,
                'emulator boot timeout is explicitly hardened')
    ok &= check('FerrostarProductionRuntimeTest' in text,
                'production Ferrostar runtime test remains the device gate')
    ok &= check('set +e' not in text and 'status=$?' not in text and 'if [ "$status" -ne 0 ]; then' not in text,
                'emulator-runner script contains no multi-command shell control flow')
    ok &= check('Dump connected Android test diagnostics' in text and 'if: failure()' in text and 'working-directory: android' in text,
                'connected-test diagnostics run as a normal GitHub step after failure')
    ok &= check('flutter build apk --release' in text and 'Publish GitHub Release assets' in text,
                'tag workflow still builds and publishes release APK')

    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
