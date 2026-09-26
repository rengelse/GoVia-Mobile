#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then echo 'Flutter SDK mangler'; exit 1; fi
flutter create --platforms=ios --org no.govia --project-name govia_mobile .
python3 - <<'PY'
import plistlib
from pathlib import Path
p=Path('ios/Runner/Info.plist')
with p.open('rb') as f: data=plistlib.load(f)
data['NSCameraUsageDescription']='GoVia bruker kameraet for å skanne sikre QR-koder fra Desktop og turinvitasjoner.'
data['NSLocationWhenInUseUsageDescription']='GoVia bruker posisjonen din til navigasjon og turplanlegging.'
data['NSLocationAlwaysAndWhenInUseUsageDescription']='GoVia kan bruke posisjon under en aktiv tur når du eksplisitt har startet navigasjon, opptak eller posisjonsdeling.'
with p.open('wb') as f: plistlib.dump(data,f)
PY
