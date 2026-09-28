import re
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
checks=[]
def check(ok,msg):
    if not ok: raise SystemExit('FAIL: '+msg)
    print('OK:',msg)

routes=(root/'lib/app/app_routes.dart').read_text()
for name in ['login','shell','trip','stages','stage','routeOverview','navigation','groupLive','invitation','newTrip','planTrip','roundTrip','recordRide','weather','notifications','poi','chat','participants','profile','offline','history','trips','discover','publishedRoute','publishRoute','savedRoutes']:
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
check('StageTransport.values' in all_dart and 'transportProfiles' in all_dart,'transport-aware planning foundation wired')
check('PublishedRoute' in all_dart and 'Oppdag' in all_dart,'community/discover client foundation wired')
check("StageTransport.motorcycle || StageTransport.car => 'driving'" in all_dart,'MC and car share road routing family without becoming the same product mode')


hardening_checks = [
    ('shared Supabase project fallback', 'pzhtlbquwvdrqqxrvhct.supabase.co', 'lib/core/config/app_config.dart'),
    ('release does not inject empty Supabase defines', '--dart-define=SUPABASE_URL', '.github/workflows/android-release.yml', True),
    ('auth shell guard', 'if (!state.signedIn && !wantsLogin)', 'lib/app/govia_app.dart'),
    ('history dummy removed', 'Vestland rundt', 'lib/features/history/presentation/history_screen.dart', True),
    ('styled route profile picker', 'RouteProfilePicker', 'lib/features/new_trip/presentation/plan_trip_screen.dart'),
]
for item in hardening_checks:
    label, needle, path, *neg = item
    text = (root / path).read_text(encoding='utf-8')
    ok = (needle not in text) if neg else (needle in text)
    check(ok, label)


# v0.1.10 hardening
checks = {
    "roundtrip backend wired": ("lib/features/new_trip/presentation/round_trip_screen.dart", "/api/v1/map/roundtrip"),
    "chat edit wired": ("lib/app/app_state.dart", "'editMessage'"),
    "chat delete wired": ("lib/app/app_state.dart", "'deleteMessage'"),
    "chat likes wired": ("lib/app/app_state.dart", "'addReaction'"),
    "community photo upload wired": ("lib/features/auth/auth_service.dart", "published-route-media"),
    "current-position start wired": ("lib/features/new_trip/presentation/plan_trip_screen.dart", "Bruk min posisjon"),
}
for label,(file,needle) in checks.items():
    data=(root/file).read_text(encoding='utf-8')
    check(needle in data,label)

print('GoVia Mobile static verification: PASS')

nav=(root/'lib/features/navigation/presentation/navigation_screen.dart').read_text(encoding='utf-8')
check('FlutterTts' in nav and 'Geolocator.getPositionStream' in nav,'GPS + TTS navigation wired')
check("'/api/v1/map/guidance'" in nav,'stored route guidance enrichment wired')
models=(root/'lib/domain/models.dart').read_text(encoding='utf-8')
check('class NavigationManeuver' in models and 'guidanceSource' in models,'normalized maneuver model wired')

# v0.1.17 profile/history foundation
phase1_checks = {
    'profile cloud read': ('lib/app/app_state.dart', "api.domain('profile', 'getById'"),
    'profile cloud update': ('lib/app/app_state.dart', "api.domain('profile', 'update'"),
    'profile avatar upload': ('lib/features/auth/auth_service.dart', "storage.from('profile-media').uploadBinary"),
    'history stage hydration': ('lib/app/app_state.dart', "api.domain('stage', 'listForTrip'"),
    'durable completion snapshots': ('lib/app/app_state.dart', "completed_trip_snapshots"),
    'pending completion cloud sync': ('lib/app/app_state.dart', "pending_trip_status_updates"),
    'history status UI': ('lib/features/history/presentation/history_screen.dart', 'Fullførte turer'),
}
for label,(file,needle) in phase1_checks.items():
    data=(root/file).read_text(encoding='utf-8')
    check(needle in data,label)

# v0.1.27 Android Auto foundation
car_manifest=(root/'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
car_build=(root/'android/app/build.gradle').read_text(encoding='utf-8')
car_desc=(root/'android/app/src/main/res/xml/automotive_app_desc.xml').read_text(encoding='utf-8')
car_root=root/'android/app/src/main/kotlin/no/govia/mobile/car'
check('androidx.car.app:app:1.7.0' in car_build and 'app-projected:1.7.0' in car_build,'AndroidX Car App projected dependency wired')
check('org.maplibre.gl:android-sdk-opengl:13.6.1' in car_build,'native MapLibre Android dependency wired')
check('com.google.android.gms.car.application' in car_manifest and 'GoViaCarAppService' in car_manifest,'Android Auto discovery + CarAppService wired')
check('androidx.car.app.category.NAVIGATION' in car_manifest,'Android Auto navigation category wired')
check('androidx.car.app.NAVIGATION_TEMPLATES' in car_manifest and 'androidx.car.app.ACCESS_SURFACE' in car_manifest,'Android Auto navigation/surface permissions wired')
check('<uses name="template"' in car_desc,'Android Auto template capability declared')
for name in ['GoViaCarAppService.kt','GoViaCarHomeScreen.kt','GoViaCarTripsScreen.kt','GoViaCarTripDetailScreen.kt','GoViaCarNavigationScreen.kt','GoViaCarRecordingCockpitScreen.kt','GoViaCarMapSurface.kt','CarRideRecordingService.kt']:
    check((car_root/name).exists(),f'Android Auto source {name}')
home=(car_root/'GoViaCarHomeScreen.kt').read_text(encoding='utf-8')
nav_car=(car_root/'GoViaCarNavigationScreen.kt').read_text(encoding='utf-8')
map_surface=(car_root/'GoViaCarMapSurface.kt').read_text(encoding='utf-8')
detail=(car_root/'GoViaCarTripDetailScreen.kt').read_text(encoding='utf-8')
overlay=(car_root/'GoViaCarCockpitOverlayView.kt').read_text(encoding='utf-8')
session=(car_root/'GoViaCarSession.kt').read_text(encoding='utf-8')
check('GoViaCarTripsScreen(carContext)' in session and 'GoViaCarHomeScreen(carContext)' not in session,'Android Auto opens directly on the trips overview')
trips=(car_root/'GoViaCarTripsScreen.kt').read_text(encoding='utf-8')
check('updateTripsOverlay' in trips and 'TAB_PLANNED' in overlay and 'TAB_ACTIVE' in overlay and 'TAB_COMPLETED' in overlay and 'TAB_RECORD' in overlay and '"Ta opp"' in overlay and 'GoViaCarRecordScreen(carContext)' in trips,'Android Auto overview uses Planlagt/Aktiv/Fullført/Ta opp controls')
check('"Turer"' not in nav_car and '"Ta opp"' not in nav_car,'Turer/Ta opp are not fixed controls during active navigation')
check('NavigationTemplate.Builder' in nav_car and 'updateNavigationOverlay' in nav_car,'Android Auto full-map navigation cockpit wired')
check('setMapActionStrip' not in nav_car and '.setNavigationInfo(' not in nav_car and '.setTitle("Avslutt")' not in nav_car and 'R.drawable.ic_car_sound' not in nav_car,'duplicate host navigation controls removed; GoVia overlay is single source of truth')
check('650, 220, 55' in nav_car and 'TextToSpeech' in nav_car,'Android Auto voice thresholds wired')
check('looksLikeCoordinates' in nav_car and 'humanRoadName' in nav_car,'coordinate leakage guard wired')
check('showPoiAlert' in nav_car and 'POI nærmer seg' in nav_car and 'poiThreshold' in nav_car,'Android Auto POI alert awareness wired')
check('MapView' in map_surface and 'createVirtualDisplay' in map_surface,'Android Auto renders a real MapLibre MapView into host Surface')
check('styles/liberty' in map_surface and 'styles/dark' in map_surface and 'LIGHT_STYLE' in map_surface and 'DARK_STYLE' in map_surface,'separate OpenFreeMap light/dark styles wired')
check('PolylineOptions' in map_surface and 'ROUTE_ORANGE' in map_surface,'real route polyline wired on map')
check('class GoViaRouteSurfaceRenderer' not in (car_root/'GoViaRouteSurfaceRenderer.kt').read_text(encoding='utf-8'),'legacy fake Canvas cockpit renderer retired')
check('updatePreviewOverlay' in detail and 'NavigationTemplate.Builder' in detail and 'MapWithContentTemplate' not in detail,'trip detail uses compact map-first preview overlay')
check('CarRideRecordingService' in car_manifest and 'foregroundServiceType="location"' in car_manifest,'Android Auto ride recording foreground service wired')
state=(root/'lib/app/app_state.dart').read_text(encoding='utf-8')
main=(root/'android/app/src/main/kotlin/no/govia/mobile/MainActivity.kt').read_text(encoding='utf-8')
check("MethodChannel('no.govia.mobile/car')" in state and 'syncState' in main,'Flutter -> Android Auto state bridge wired')
check('drainRecordedRides' in state and 'recorded_rides_json' in main,'Android Auto recordings import bridge wired')
pubspec_text=(root/'pubspec.yaml').read_text(encoding='utf-8')
version_match=re.search(r'^version: ([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)$', pubspec_text, re.MULTILINE)
check(version_match is not None,'pubspec semantic build version present')
release_version=version_match.group(1) if version_match else ''
check((root/'README.md').read_text(encoding='utf-8').startswith(f'# GoVia Mobile v{release_version}'),'README version matches pubspec')
check((root/'RELEASE.md').read_text(encoding='utf-8').startswith(f'# GoVia Mobile v{release_version}'),'RELEASE version matches pubspec')
profile_screen=(root/'lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8')
check("'system': 'Automatisk'" in profile_screen and "'light': 'Lys'" in profile_screen and "'dark': 'Mørk'" in profile_screen,'Android Auto theme selector exposes automatic/light/dark')
check("'themeMode': androidAutoThemeMode" in state and 'android_auto_theme_mode' in state,'Android Auto theme preference persists and bridges to car host')
check('Configuration.UI_MODE_NIGHT_MASK' in nav_car and 'resolveDarkMode' in nav_car,'automatic Android Auto host day/night mode wired')
record=(car_root/'GoViaCarRecordScreen.kt').read_text(encoding='utf-8')
recording=(car_root/'GoViaCarRecordingCockpitScreen.kt').read_text(encoding='utf-8')
check('GoViaCarRecordingCockpitScreen' in record and 'Start opptak' in record,'record flow enters cockpit after starting recording')
check('GoViaCarMapSurface' in recording and 'recordingMode = true' in recording and 'Stopp og lagre' in recording,'recording cockpit uses real map + REC state')
workflow=(root/'.github/workflows/android-release.yml').read_text(encoding='utf-8')
check('Upload debug APK artifact' in workflow and 'app-debug.apk' in workflow,'main CI uploads downloadable debug APK')

map_surface=(car_root/'GoViaCarMapSurface.kt').read_text(encoding='utf-8')
recording=(car_root/'GoViaCarRecordingCockpitScreen.kt').read_text(encoding='utf-8')
overlay=(car_root/'GoViaCarCockpitOverlayView.kt').read_text(encoding='utf-8')
check('LIGHT_STYLE' in map_surface and 'DARK_STYLE' in map_surface and 'styles/liberty' in map_surface and 'styles/dark' in map_surface,'real Android Auto day/dark style switching restored')
check('NIGHT_LIFT' in map_surface and 'if (darkMode) DARK_STYLE else LIGHT_STYLE' in map_surface,'dark mode keeps readable projected-display lift without reusing day style')
check('.tilt(28.0)' in map_surface and '.zoom(15.9)' in map_surface,'Android Auto follow camera tuned for readable cockpit context')
check('GoViaCarCockpitOverlayView' in map_surface and 'updateNavigationOverlay' in nav_car,'responsive GoVia navigation overlay wired on real map')
check('Mode.PREVIEW' in overlay and 'drawPreview' in overlay and 'POI nærmer seg' in overlay and 'drawTurnIcon' in overlay and 'navigationState.tripName' not in overlay[overlay.find('private fun drawNavigation(canvas: Canvas)'):overlay.find('// POI card:', overlay.find('private fun drawNavigation(canvas: Canvas)'))],'compact maneuver-only guidance card wired')
check('updateRecordingOverlay' in recording and 'NavigationTemplate.Builder' in recording,'recording mode uses full-map cockpit without PaneTemplate obstruction')
check('PaneTemplate.Builder(pane)' not in recording and 'MapWithContentTemplate.Builder' not in recording,'oversized recording content card removed')
check('Stopp og lagre' in recording and 'REC' in overlay and 'GPS aktiv' in overlay,'recording cockpit exposes REC state, GPS and stop/save action')

nav_exit = (root/'android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').read_text(encoding='utf-8')
rec_exit = (root/'android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRecordingCockpitScreen.kt').read_text(encoding='utf-8')
check('screenManager.popToRoot()' in nav_exit, 'navigation exit returns to root')
check('screenManager.popToRoot()' in rec_exit, 'recording stop returns to root')
check('screenManager.pop()' not in nav_exit and 'screenManager.pop()' not in rec_exit, 'no single-pop exit trap remains')


home=(root/'android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarHomeScreen.kt').read_text(encoding='utf-8')
trips=(root/'android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripsScreen.kt').read_text(encoding='utf-8')
check('.setActionStrip(requiredActionStrip)' in home and '.addAction(Action.APP_ICON)' in home, 'home NavigationTemplate required ActionStrip')
check('.setActionStrip(requiredActionStrip)' in trips and '.addAction(Action.APP_ICON)' in trips, 'trips NavigationTemplate required ActionStrip')
check('NavigationTemplate.Builder().build()' not in home and 'NavigationTemplate.Builder().build()' not in trips, 'no bare NavigationTemplate build on home/trips')
print(f'GoVia Mobile v{release_version} version-contract verification: PASS')
