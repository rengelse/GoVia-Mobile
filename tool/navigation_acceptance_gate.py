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
    printable = ' '.join(str(part) for part in cmd)
    print(f'\n== {label} ==', flush=True)
    print(f'COMMAND: {printable}', flush=True)
    completed = subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    output = completed.stdout or ''
    if output:
        print(output, end='' if output.endswith('\n') else '\n', flush=True)
    status = 'PASS' if completed.returncode == 0 else 'FAIL'
    print(f'RESULT: {status} (exit code {completed.returncode})', flush=True)
    return completed.returncode == 0
def main():
    ok=True
    app_gradle = (ROOT/'android/app/build.gradle').read_text(encoding='utf-8')
    desugar_enabled = 'coreLibraryDesugaringEnabled true' in app_gradle
    desugar_dependency = 'coreLibraryDesugaring' in app_gradle and 'desugar_jdk_libs' in app_gradle
    print(('OK  ' if desugar_enabled else 'FAIL') + ' Android core library desugaring enabled')
    print(('OK  ' if desugar_dependency else 'FAIL') + ' desugar_jdk_libs dependency configured')
    import re
    min_sdk_match = re.search(r'\bminSdk\s+(\d+)', app_gradle)
    min_sdk_ok = bool(min_sdk_match and int(min_sdk_match.group(1)) >= 25)
    print(('OK  ' if min_sdk_ok else 'FAIL') + ' Android minSdk >= 25 for Ferrostar Core 0.53.0')
    override_absent = 'tools:overrideLibrary="com.stadiamaps.ferrostar.core"' not in (ROOT/'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
    print(('OK  ' if override_absent else 'FAIL') + ' no Ferrostar manifest compatibility override')
    ok &= desugar_enabled and desugar_dependency and min_sdk_ok and override_absent
    for p in REQUIRED:
        x=p.exists(); print(('OK  ' if x else 'FAIL')+f' required: {p.relative_to(ROOT)}'); ok &= x
    for p in FORBIDDEN:
        x=not p.exists(); print(('OK  ' if x else 'FAIL')+f' forbidden absent: {p.relative_to(ROOT)}'); ok &= x
    ok &= run('static release preflight',[sys.executable,'tool/release_preflight.py'])
    ok &= run('authoritative runtime contract verifier',[sys.executable,'tool/verify_mobile.py'])
    flutter=shutil.which('flutter')
    if not flutter:
        print('BLOCKED: Flutter SDK unavailable'); return 2
    ok &= run('flutter analyze',[flutter,'analyze'])
    ok &= run('flutter test',[flutter,'test','--reporter','expanded'])
    gradle=os.environ.get('GOVIA_GRADLE_COMMAND','').strip() or (str(ROOT/'android/gradlew') if (ROOT/'android/gradlew').exists() else (shutil.which('gradle') or ''))
    if not gradle:
        print('BLOCKED: Gradle unavailable'); return 2
    ok &= run('native JVM unit tests',[gradle,':app:testDebugUnitTest','--no-daemon','--build-cache'],ROOT/'android')
    return 0 if ok else 1
if __name__=='__main__': raise SystemExit(main())
