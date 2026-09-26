from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
checks=[]
def check(ok,msg):
    if not ok: raise SystemExit('FAIL: '+msg)
    print('OK:',msg)

routes=(root/'lib/app/app_routes.dart').read_text()
for name in ['login','shell','trip','stages','stage','routeOverview','navigation','groupLive','invitation','newTrip','planTrip','roundTrip','recordRide','weather','notifications','poi','chat','participants','profile','offline','history','trips']:
    check(re.search(rf'static const {name}\s*=',routes) is not None, f'route {name}')
all_dart='\n'.join(p.read_text(errors='ignore') for p in (root/'lib').rglob('*.dart'))
check('Økonomi' not in all_dart and 'Legg til utgift' not in all_dart,'economy screens excluded')
check("'/api/v1/map/route'" in all_dart,'real GoVia route endpoint wired')
check("'/api/v1/map/geocode'" in all_dart,'real GoVia geocode endpoint wired')
check('selectedStart' in all_dart and 'selectedEnd' in all_dart,'start/end require selected geocoded places')
check('assets/brand/govia-logo-horizontal.png' in all_dart,'Desktop brand logo wired')
check('sb_publishable_' in all_dart,'public Supabase publishable key has production default')
check('api.github.com/repos' in all_dart,'GitHub updater wired')
manifest=(root/'android/app/src/main/AndroidManifest.xml').read_text()
for perm in ['CAMERA','ACCESS_FINE_LOCATION','REQUEST_INSTALL_PACKAGES']:
    check(perm in manifest,f'Android permission {perm}')
check('govia.no' in manifest and '/m/' in manifest,'Desktop handoff deep-link reserved')
check((root/'docs/BACKEND-GAPS.md').exists(),'backend gaps documented')
print('GoVia Mobile static verification: PASS')
