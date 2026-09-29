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
check('photon.komoot.io' in all_dart,'direct Photon/OpenStreetMap place search wired')
check("'/api/v1/map/geocode'" not in all_dart,'Flutter place search no longer depends on GoVia geocode endpoint')
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

# Android Auto / Android for Cars architecture contract
car_manifest=(root/'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
car_build=(root/'android/app/build.gradle').read_text(encoding='utf-8')
car_desc=(root/'android/app/src/main/res/xml/automotive_app_desc.xml').read_text(encoding='utf-8')
car_root=root/'android/app/src/main/kotlin/no/govia/mobile/car'
check('androidx.car.app:app:1.7.0' in car_build and 'app-projected:1.7.0' in car_build,'stable AndroidX Car App projected dependency wired')
check('org.maplibre.gl:android-sdk-opengl:13.6.1' in car_build,'native MapLibre Android dependency wired')
check('androidx.car.app.category.NAVIGATION' in car_manifest,'Android Auto navigation category wired')
check('androidx.car.app.NAVIGATION_TEMPLATES' in car_manifest and 'androidx.car.app.ACCESS_SURFACE' in car_manifest,'navigation + Surface permissions wired')
check('<uses name="template"' in car_desc,'Android Auto template capability declared')
for name in ['GoViaCarAppService.kt','GoViaCarSession.kt','GoViaCarRuntime.kt','GoViaNavigationService.kt','GoViaCarTripsScreen.kt','GoViaCarTripDetailScreen.kt','GoViaCarNavigationScreen.kt','GoViaCarRecordScreen.kt','GoViaCarRecordingCockpitScreen.kt','GoViaCarSearchScreen.kt',
    'GoViaCarLocationPermissionScreen.kt','GoViaCarMapSurface.kt','CarRideRecordingService.kt']:
    check((car_root/name).exists(),f'Android Auto source {name}')

runtime=(car_root/'GoViaCarRuntime.kt').read_text(encoding='utf-8')
session=(car_root/'GoViaCarSession.kt').read_text(encoding='utf-8')
surface=(car_root/'GoViaCarMapSurface.kt').read_text(encoding='utf-8')
nav=(car_root/'GoViaCarNavigationScreen.kt').read_text(encoding='utf-8')
nav_service=(car_root/'GoViaNavigationService.kt').read_text(encoding='utf-8')
trips=(car_root/'GoViaCarTripsScreen.kt').read_text(encoding='utf-8')
detail=(car_root/'GoViaCarTripDetailScreen.kt').read_text(encoding='utf-8')
record=(car_root/'GoViaCarRecordScreen.kt').read_text(encoding='utf-8')
recording=(car_root/'GoViaCarRecordingCockpitScreen.kt').read_text(encoding='utf-8')
search=(car_root/'GoViaCarSearchScreen.kt').read_text(encoding='utf-8')

check('setSurfaceCallback(mapSurface)' in runtime and 'setSurfaceCallback(null)' in runtime,'SurfaceCallback owned by session runtime')
for screen_file in car_root.glob('*Screen.kt'):
    source=screen_file.read_text(encoding='utf-8')
    check('setSurfaceCallback(' not in source and 'mapSurface.close()' not in source,f'{screen_file.name} does not own car surface lifecycle')
check('existingDisplay.resize(' in surface and 'existingDisplay.setSurface(surface)' in surface,'surface resize/rebind avoids unnecessary MapLibre rebuild')
check('GoViaCarCockpitOverlayView' not in surface and 'FrameLayout.LayoutParams.MATCH_PARENT' in surface,'app-provided Surface is map-only; host templates own visible UI')

check('class GoViaNavigationService : Service()' in nav_service,'dedicated navigation service wired')
check('navigationStarted()' in nav_service and 'navigationEnded()' in nav_service and 'manager.updateTrip(' in nav_service,'NavigationManager start/end/updateTrip metadata wired')
check('onAutoDriveEnabled()' in nav_service and 'startAutoDriveSimulation()' in nav_service,'AutoDrive simulation required for review wired')
check('USAGE_ASSISTANCE_NAVIGATION_GUIDANCE' in nav_service and 'AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK' in nav_service,'navigation audio focus contract wired')
check('CarAppExtender.Builder()' in nav_service and 'CATEGORY_NAVIGATION' in nav_service,'turn-by-turn car notification contract wired')
check('bindService(' in runtime and 'GoViaNavigationService::class.java' in runtime,'Session runtime binds navigation service')
check('android:name=".car.GoViaNavigationService"' in car_manifest and car_manifest.count('android:process=":car"') >= 3,'CarAppService/navigation/recording services share dedicated car process')
check('android:name=".car.GoViaCarAppService"' in car_manifest and 'android:intentMatchingFlags="allowNullAction"' in car_manifest,'CarAppService allows Android 16+ host null-action binding')

check('NavigationTemplate.Builder' in nav and '.setNavigationInfo(' in nav and '.setDestinationTravelEstimate(' in nav,'active navigation uses native NavigationTemplate routing UI')
check('.setMapActionStrip(' in nav and 'Action.PAN' in nav and 'ic_car_recenter' in nav,'host-managed navigation map controls wired')
check('updateNavigationOverlay' not in nav and 'invisibleRequiredActionStrip' not in nav,'custom cockpit/ghost-action workaround removed from navigation')

home = (car_root/'GoViaCarHomeScreen.kt').read_text(encoding='utf-8')
session = (car_root/'GoViaCarSession.kt').read_text(encoding='utf-8')
check('GoViaCarHomeScreen(carContext, runtime)' in session, 'native GoVia home is Session root')
check('GridTemplate.Builder' in home and 'setHeaderAction(Action.APP_ICON)' in home, 'native GoVia home uses branded GridTemplate + host app icon')
check(all(x in home for x in ['\"Turer\"', '\"Ta opp tur\"', '\"Søk destinasjon\"']), 'native GoVia home exposes core entry points')
check('R.mipmap.ic_launcher' in surface, 'MapLibre vehicle marker uses GoVia application icon')
check('androidx.car.app.theme' in car_manifest and '@style/CarAppTheme' in car_manifest,'Android Auto Car App theme wired')
styles=(root/'android/app/src/main/res/values/styles.xml').read_text(encoding='utf-8')
check('carColorPrimary' in styles and 'govia_car_primary' in styles,'GoVia primary car color wired')
check(not (car_root/'GoViaCarCockpitOverlayView.kt').exists() and not (car_root/'GoViaCarTemplateCompat.kt').exists(),'obsolete custom cockpit/ghost-action sources removed')

check('TabTemplate.Builder' in trips and trips.count('.addTab(') == 4,'trip browser uses native TabTemplate within 2-4 tab requirement')
for label in ['"Planlagt"','"Aktiv"','"Fullført"','"Mer"','"Søk destinasjon"','"Ta opp tur"']:
    check(label in trips,f'trip browser exposes {label}')
check('MapWithContentTemplate.Builder' in detail and 'PaneTemplate.Builder' in detail and 'MapController.Builder' in detail,'route preview uses MapWithContentTemplate on Car API 7+')
check('carContext.carAppApiLevel < 7' in detail,'route preview has pre-API-7 fallback')
check('PaneTemplate.Builder' in record and 'NavigationTemplate.Builder' not in record,'record ready flow uses native PaneTemplate')
check('MapWithContentTemplate.Builder' in recording and 'NavigationTemplate.Builder' not in recording,'recording map flow uses native map/content template')
check('SearchTemplate.Builder(this)' in search and 'https://photon.komoot.io/api/' in search and '/api/v1/map/route' in search,'native destination search wired')
check('/api/v1/map/geocode' not in search and 'URLEncoder.encode' in search,'Android Auto place search bypasses GoVia geocode backend')

check('androidx.car.app.action.NAVIGATE' in car_manifest and 'android:scheme="geo"' in car_manifest,'navigation intent filter wired')
check('CarContext.ACTION_NAVIGATE' in session and 'override fun onNewIntent(intent: Intent)' in session,'Session handles navigation intents')
check('coordinateQuery' in session and 'coordinateResult' in search,'direct geo coordinate navigation wired')
permission_screen=(car_root/'GoViaCarLocationPermissionScreen.kt').read_text(encoding='utf-8')
check('requestPermissions(' in permission_screen and 'ParkedOnlyOnClickListener' in permission_screen and 'ACCESS_FINE_LOCATION' in permission_screen,'car-host location permission flow wired')
check('android.intent.action.NAVIGATE' in car_manifest,'generic Android NAVIGATE intent filter wired')

bridge_store=(root/'android/app/src/main/kotlin/no/govia/mobile/CarBridgeStore.kt').read_text(encoding='utf-8')
repository_text=(car_root/'GoViaCarRepository.kt').read_text(encoding='utf-8')
state=(root/'lib/app/app_state.dart').read_text(encoding='utf-8')
check('AtomicFile' in bridge_store and 'state.lock' in bridge_store,'phone/car bridge remains process-safe')
check('bridge.readState()' in repository_text,'car repository reads process-safe snapshot')
check('void _scheduleAndroidAutoSync()' in state and '@override\n  void notifyListeners()' not in state and 'if (encoded == _lastAndroidAutoStateJson) return;' in state,'phone UI notifications stay detached from Android Auto writes')

pubspec_text=(root/'pubspec.yaml').read_text(encoding='utf-8')
version_match=re.search(r'^version: ([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)$', pubspec_text, re.MULTILINE)
check(version_match is not None,'pubspec semantic build version present')
release_version=version_match.group(1) if version_match else ''
check((root/'README.md').read_text(encoding='utf-8').startswith(f'# GoVia Mobile v{release_version}'),'README version matches pubspec')
check((root/'RELEASE.md').read_text(encoding='utf-8').startswith(f'# GoVia Mobile v{release_version}'),'RELEASE version matches pubspec')
workflow=(root/'.github/workflows/android-release.yml').read_text(encoding='utf-8')
check('Upload debug APK artifact' in workflow and 'flutter build apk --release' in workflow,'GitHub APK workflow preserved')

# Navigation Core v2 foundation v0.1.83+
nav_engine=(root/'lib/features/navigation/domain/navigation_engine.dart').read_text(encoding='utf-8')
nav_route=(root/'lib/features/navigation/domain/navigation_route.dart').read_text(encoding='utf-8')
nav_session=(root/'lib/features/navigation/domain/navigation_session.dart').read_text(encoding='utf-8')
native_core=(car_root/'NavigationCoreV2.kt').read_text(encoding='utf-8')
plan_trip=(root/'lib/features/new_trip/presentation/plan_trip_screen.dart').read_text(encoding='utf-8')
phone_nav=(root/'lib/features/navigation/presentation/navigation_screen.dart').read_text(encoding='utf-8')
check('class NavigationSession' in nav_session and '_bestProjection' in nav_session,'Navigation Core v2 phone session owns progress/matching')
check('effectiveSpeed' in nav_session and 'baselineSpeed' in nav_session,'adaptive phone ETA lives in Navigation Core v2')
check("'profile': profile" in plan_trip and "'preferences': routePreferences.toJson()" in plan_trip,'route profile + preference contract sent by planner')
check("'profile': stage.routeProfile" in phone_nav and "stage.routePreferences.toJson()" in phone_nav,'phone rerouting preserves route character')
check('session.rerouteRequired' in nav_service and 'requestReroute(' in nav_service and '25_000L' in nav_service,'Android Auto off-route rerouting is driven by Navigation Core v2')
check('.put("profile", sourceStage.routeProfile)' in nav_service and 'routePreferences' in nav_service,'Android Auto rerouting preserves route character')
check('class NavigationCoreV2' in native_core and 'estimateRemainingSeconds' in native_core and 'smoothedMovingSpeed' in native_core,'Android Auto adaptive ETA lives in native Navigation Core v2')
check('routeRevision' in runtime and 'mapSurface.updateRoute(state.routeGeometry)' in runtime,'Android Auto reroute geometry refresh wired')

# Android Auto ordinary-route guidance + Photon language hardening
check('ensureGuidanceStage' in nav_service and 'geometry-emergency' in nav_service,'Android Auto keeps geometry-derived guidance as emergency fallback only')
check('state.currentStep == null || state.rerouting' not in nav and 'Step.Builder("Følg ruten")' in nav,'active navigation cannot hang forever on missing maneuver metadata')
check('lang=no' not in search and 'Accept-Language' in search,'Android Auto Photon search uses supported language negotiation')
check("'lang': 'no'" not in plan_trip and 'Accept-Language' in plan_trip,'phone Photon search uses supported language negotiation')
place_search_test=(root/'test/place_search_hardening_test.dart').read_text(encoding='utf-8')
check('contains(\"photon.komoot.io\")' not in place_search_test, 'place-search regression test stays analyzer-clean for prefer_single_quotes')


car_models_v2=(car_root/'GoViaCarModels.kt').read_text(encoding='utf-8')
native_test=(root/'android/app/src/test/kotlin/no/govia/mobile/car/NavigationCoreV2Test.kt').read_text(encoding='utf-8')
check('class NavigationRoute' in nav_route and 'shapeIndex' in nav_route and 'routeProgressMeters' in nav_route,'canonical NavigationRoute anchors maneuvers to route geometry')
check("'version': 3" in state and "'type': maneuver.type" in state and "'roadRef': maneuver.roadRef" in state and "'confidence': maneuver.confidence" in state,'Android Auto bridge v3 preserves full maneuver semantics')
check('val type: String' in car_models_v2 and 'val modifier: String' in car_models_v2 and 'val roadRef: String' in car_models_v2 and 'val confidence: Double' in car_models_v2,'Android Auto maneuver model preserves canonical maneuver fields')
check('private fun maneuverType(maneuver: CarManeuver)' in nav_service and 'maneuver.type.lowercase' in nav_service and 'maneuverType(cue' not in nav_service,'Android Auto uses structured maneuver metadata, not instruction-text parsing')
check('firstOrNull { it.status == "active" }' in nav_service and 'nextTrip.stages.flatMap' not in nav_service,'Android Auto session owns exactly one active Stage')
check('START_STICKY' in nav_service and 'restorePersistedNavigation' in nav_service and 'startForegroundService' in runtime,'Android Auto foreground lifecycle + process recovery wired')
check('Run native Navigation Core v2 tests' in workflow and 'testDebugUnitTest' in workflow,'CI runs native Navigation Core v2 tests')
check('arrival requires three credible fixes' in native_test and 'off route requires repeated credible fixes' in native_test and 'poor accuracy does not advance route state' in native_test,'native Navigation Core v2 behavior tests cover arrival/off-route/GPS quality')


# Development-only navigation simulator
dev_features=(root/'lib/core/config/dev_features.dart').read_text(encoding='utf-8')
dev_screen=(root/'lib/dev/navigation_simulator/navigation_simulator_screen.dart').read_text(encoding='utf-8')
dev_controller=(root/'lib/dev/navigation_simulator/simulator_controller.dart').read_text(encoding='utf-8')
dev_models=(root/'lib/dev/navigation_simulator/simulator_models.dart').read_text(encoding='utf-8')
production_main=(root/'lib/main.dart').read_text(encoding='utf-8')
production_app=(root/'lib/app/govia_app.dart').read_text(encoding='utf-8')
profile_screen=(root/'lib/features/profile/presentation/profile_screen.dart').read_text(encoding='utf-8')
app_routes=(root/'lib/app/app_routes.dart').read_text(encoding='utf-8')
check("bool.fromEnvironment(" in dev_features and "'GOVIA_NAV_SIMULATOR'" in dev_features and 'defaultValue: false' in dev_features,'simulator uses one removable compile-time development gate')
check('DevFeatures.navigationSimulator' in production_app and 'NavigationSimulatorScreen' in production_app,'ordinary app routes to simulator only through development gate')
check('Utviklerverktøy' in profile_screen and 'AppRoutes.navigationSimulator' in profile_screen and 'DevFeatures.navigationSimulator' in profile_screen,'development APK exposes simulator from Profile')
check("navigationSimulator = '/dev/navigation-simulator'" in app_routes,'simulator has isolated developer route')
check('--dart-define=GOVIA_NAV_SIMULATOR=true' in workflow and '-t lib/main_dev.dart' not in workflow,'single GitHub APK carries removable simulator gate without alternate entrypoint')
check('By + rundkjøringer' in dev_models and 'Svingete fjellvei' in dev_models and 'Stress / feilkjøring' in dev_models,'multiple simulator routes wired')
check(all(x in dev_controller for x in ['injectOffRoute','injectGpsJitter','injectGpsLoss','injectStop','jumpToArrival','jumpToNextManeuver']),'simulator fault injection controls wired')
check('locationStream' in phone_nav and 'rerouteOverride' in phone_nav,'real navigation screen accepts injected dev GPS without duplicating navigation UI')

# Navigation tests must follow Navigation Core v2 ownership.
session_test=(root/'test/navigation_session_hardening_test.dart').read_text(encoding='utf-8')
cockpit_test=(root/'test/navigation_cockpit_test.dart').read_text(encoding='utf-8')
core_test=(root/'test/navigation_core_v2_test.dart').read_text(encoding='utf-8')
check('class NavigationSession' in nav_session and '_arrivalFixes >= 3' in nav_session,'arrival ownership is inside Navigation Core v2')
check('_bestProjection' in nav_session and 'headingDeltaDegrees' in nav_session and 'accuracyMeters' in nav_session,'route matching uses continuity, heading and GPS quality')
check('arrival requires three consecutive credible fixes' in core_test and 'off-route state requires three repeated fixes' in core_test and 'poor GPS accuracy cannot jump navigation progress' in core_test,'Navigation Core v2 behavioral scenario tests wired')

workflow=(root/'.github/workflows/android-release.yml').read_text(encoding='utf-8')
check('--dart-define=GOVIA_NAV_SIMULATOR=true' in workflow,'GitHub APK builds explicitly enable navigation simulator during development')
route_key=(root/'lib/core/map/route_render_key.dart').read_text(encoding='utf-8')
route_test=(root/'test/route_candidate_hardening_test.dart').read_text(encoding='utf-8')
check('String routeRenderKey(' in route_key,'route render identity is isolated in a pure testable helper')
check('routeRenderKey(original' in route_test and 'routeRenderKey(changed' in route_test,'route remount hardening uses behavioural geometry-key test')
check('_routeRenderKey(points, connectPoints, showRiders)' not in route_test,'obsolete route remount source-string expectation is absent')
print(f'GoVia Mobile v{release_version} Android for Cars contract verification: PASS')

# Multi-stage canonical trip foundation
models_text=(root/'lib/domain/models.dart').read_text(encoding='utf-8')
state_text=(root/'lib/app/app_state.dart').read_text(encoding='utf-8')
stages_ui=(root/'lib/features/trips/presentation/stages_screen.dart').read_text(encoding='utf-8')
trip_detail=(root/'lib/features/trips/presentation/trip_detail_screen.dart').read_text(encoding='utf-8')
map_widgets=(root/'lib/core/widgets/govia_widgets.dart').read_text(encoding='utf-8')
stage_picker=(car_root/'GoViaCarStageSelectionScreen.kt').read_text(encoding='utf-8')
car_models=(car_root/'GoViaCarModels.kt').read_text(encoding='utf-8')
car_repo=(car_root/'GoViaCarRepository.kt').read_text(encoding='utf-8')
check('enum StageStatus' in models_text and 'class StageWaypoint' in models_text,'stage status + canonical stage waypoint model wired')
check('final List<StageWaypoint> waypoints' in models_text and 'List<StageWaypoint> get pois' in models_text,'stage owns via/stops/POI metadata')
check("final nestedTripStages = tripRaw['stages'];" in state_text and "snapshot['stages'] is List" in state_text,'handoff accepts legacy and canonical nested stages')
check("active_stage_id_${active.id}" in state_text and 'item.copyWith(status: StageStatus.completed)' in state_text,'arbitrary stage progress is persisted independently')
check("stages.length > 1 ? 'Velg etappe' : 'Start navigasjon'" in trip_detail and 'startNavigationStage(stage)' in stages_ui,'mobile requires explicit stage choice for multi-stage trips')
check('waypoints: s.waypoints' in (root/'lib/features/trips/presentation/stage_detail_screen.dart').read_text(encoding='utf-8') and 'widget.waypoints' in map_widgets,'imported stage POI/stops render on mobile route maps')
check((car_root/'GoViaCarStageSelectionScreen.kt').exists() and 'stages = listOf(stage)' in stage_picker,'Android Auto stage selector navigates only selected stage')
check('val waypoints: List<CarWaypoint>' in car_models and 'toWaypoints()' in car_repo,'Android Auto receives stage-owned waypoint/POI metadata')
check('activeStagePois' in nav_service and 'stage.waypoints.filter { it.kind == "poi" }' in nav_service,'Android Auto POI alerts prefer selected stage POI')
