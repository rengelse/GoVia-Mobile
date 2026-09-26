$ErrorActionPreference = 'Stop'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter SDK mangler i PATH.' }
$backup = Join-Path $env:TEMP 'govia-mobile-android-backup'
Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue
New-Item $backup -ItemType Directory | Out-Null
$files = @(
  'android/app/src/main/AndroidManifest.xml',
  'android/app/build.gradle',
  'android/settings.gradle',
  'android/build.gradle',
  'android/gradle.properties',
  'android/app/src/main/kotlin/no/govia/mobile/MainActivity.kt',
  'test/widget_test.dart'
)
foreach ($f in $files) {
  if (Test-Path $f) {
    $dest = Join-Path $backup $f
    New-Item (Split-Path $dest) -ItemType Directory -Force | Out-Null
    Copy-Item $f $dest -Force
  }
}
flutter create --platforms=android --org no.govia --project-name govia_mobile .
foreach ($f in $files) {
  $src = Join-Path $backup $f
  if (Test-Path $src) {
    New-Item (Split-Path $f) -ItemType Directory -Force | Out-Null
    Copy-Item $src $f -Force
  }
}
Write-Host 'Android runner/wrapper er generert og GoVia-konfigurasjonen er gjenopprettet.'
