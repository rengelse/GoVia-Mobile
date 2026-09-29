#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/govia-navigation-guidance-v1-smoke.jar"
kotlinc \
  "$ROOT/android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarModels.kt" \
  "$ROOT/android/app/src/main/kotlin/no/govia/mobile/car/NavigationGuidanceV1.kt" \
  "$ROOT/tool/navigation_guidance_kotlin_smoke.kt" \
  -include-runtime -d "$OUT"
java -jar "$OUT"
