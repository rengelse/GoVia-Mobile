#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/govia-navigation-core-smoke.jar"
kotlinc \
  "$ROOT/android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarModels.kt" \
  "$ROOT/android/app/src/main/kotlin/no/govia/mobile/car/NavigationCoreV2.kt" \
  "$ROOT/android/app/src/main/kotlin/no/govia/mobile/car/NavigationHardening.kt" \
  "$ROOT/tool/navigation_core_kotlin_smoke.kt" \
  -include-runtime -d "$OUT"
java -jar "$OUT"
rm -f "$OUT"
