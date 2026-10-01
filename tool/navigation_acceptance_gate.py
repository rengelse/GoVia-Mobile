#!/usr/bin/env python3
from pathlib import Path
import os, shutil, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    ROOT/'android/app/src/main/kotlin/no/govia/mobile/car/FerrostarNavigationRuntime.kt',
    ROOT/'android/app/src/main/kotlin/no/govia/mobile/car/FerrostarRouteAdapter.kt',
    ROOT/'android/app/src/main/kotlin/no/govia/mobile/PhoneNavigationBridge.kt',
    ROOT/'android/app/src/androidTest/kotlin/no/govia/mobile/car/FerrostarProductionRuntimeTest.kt',
    ROOT/'lib/features/navigation/domain/native_navigation_state.dart',
    ROOT/'test/native_navigation_bridge_contract_test.dart',
    ROOT/'docs/FERROSTAR-PRODUCTION-RUNTIME.md',
]
FORBIDDEN = [
    ROOT/'android/app/src/main/kotlin/no/govia/mobile/car/NavigationCoreV2.kt',
    ROOT/'android/app/src/main/kotlin/no/govia/mobile/car/NavigationGuidanceV1.kt',
    ROOT/'lib/features/navigation/domain/navigation_route.dart',
    ROOT/'lib/features/navigation/domain/navigation_session.dart',
    ROOT/'lib/features/navigation/domain/navigation_guidance.dart',
    ROOT/'android/ferrostar-poc',
]
def run(label, cmd, cwd=ROOT):
    print(f'\n== {label} ==')
    return subprocess.run(cmd, cwd=cwd).returncode == 0
def main():
    ok=True
    for p in REQUIRED:
        x=p.exists(); print(('OK  ' if x else 'FAIL')+f' required: {p.relative_to(ROOT)}'); ok &= x
    for p in FORBIDDEN:
        x=not p.exists(); print(('OK  ' if x else 'FAIL')+f' forbidden absent: {p.relative_to(ROOT)}'); ok &= x
    ok &= run('authoritative runtime contract verifier',[sys.executable,'tool/verify_mobile.py'])
    flutter=shutil.which('flutter')
    if not flutter:
        print('BLOCKED: Flutter SDK unavailable'); return 2
    ok &= run('flutter analyze',[flutter,'analyze'])
    ok &= run('flutter test',[flutter,'test'])
    gradle=os.environ.get('GOVIA_GRADLE_COMMAND','').strip() or (str(ROOT/'android/gradlew') if (ROOT/'android/gradlew').exists() else (shutil.which('gradle') or ''))
    if not gradle:
        print('BLOCKED: Gradle unavailable'); return 2
    ok &= run('native JVM unit tests',[gradle,':app:testDebugUnitTest','--no-daemon','--build-cache'],ROOT/'android')
    return 0 if ok else 1
if __name__=='__main__': raise SystemExit(main())
