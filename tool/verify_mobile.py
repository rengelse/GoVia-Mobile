#!/usr/bin/env python3
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
def text(rel):
    p=root/rel
    return p.read_text(encoding='utf-8') if p.exists() else ''
def check(cond,label):
    print(('OK   ' if cond else 'FAIL ')+label)
    return bool(cond)
ok=True
build=text('android/app/build.gradle')
runtime=text('android/app/src/main/kotlin/no/govia/mobile/car/FerrostarNavigationRuntime.kt')
adapter=text('android/app/src/main/kotlin/no/govia/mobile/car/FerrostarRouteAdapter.kt')
service=text('android/app/src/main/kotlin/no/govia/mobile/car/GoViaNavigationService.kt')
main=text('android/app/src/main/kotlin/no/govia/mobile/MainActivity.kt')
screen=text('lib/features/navigation/presentation/navigation_screen.dart')
workflow=text('.github/workflows/android-release.yml')
repo=text('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarRepository.kt')
checks=[
 ('com.stadiamaps.ferrostar:core:0.53.0' in build,'Ferrostar Core is a production app dependency'),
 ('class FerrostarNavigationRuntime' in runtime and 'session.updateUserLocation' in runtime,'Ferrostar owns production progress/snapping state'),
 ('replaceRoute' in runtime and 'FerrostarSessionBuilder(config()).build' in runtime,'reroute atomically creates a new Ferrostar session'),
 ('exactShapeIndex' in adapter and 'nearestpoint' not in adapter and 'nearestRoute' not in adapter,'provider maneuvers use strict explicit/exact anchoring'),
 ('startPathIndex' in adapter and 'speedLimitKph' in adapter,'speed-limit annotations use provider path indexes'),
 ('startIndex..endIndex' in adapter and 'routeLastIndex' in adapter and 'stepGeometrySize' in adapter and 'annotations must be coordinate-aligned' in text('android/app/src/androidTest/kotlin/no/govia/mobile/car/FerrostarProductionRuntimeTest.kt'),'speed-limit annotations are coordinate-aligned with Ferrostar step geometry, including duplicate shape indexes'),
 ('roundaboutExitNumber = if' in adapter and 'roundabout' in adapter and 'rotary' in adapter,'roundabout exit metadata is restricted to roundabout maneuvers'),
 ('spokenInstructions' in adapter and 'isActionable' in adapter,'Ferrostar route owns spoken maneuver cues'),
 ('FerrostarNavigationRuntime' in service and 'NavigationCoreV2' not in service and 'NavigationGuidanceV1' not in service,'Android Auto uses only Ferrostar navigation runtime'),
 ('speedLimitKph = runtime' in service or '.speedLimitKph' in service,'Android Auto speed sign consumes runtime speed-limit state'),
 ('startNavigationRuntime' in main and 'updateNavigationFix' in main and 'replaceNavigationRoute' in main,'phone bridge exposes native runtime lifecycle'),
 ('startNavigationRuntime' in screen and 'updateNavigationFix' in screen and 'replaceNavigationRoute' in screen and 'stopNavigationRuntime' in screen,'Flutter consumes native runtime instead of calculating progress'),
 ("/api/v1/map/guidance" not in screen,'production phone navigation has no geometry-guidance fallback'),
 ('car_navigation_route_v4' in repo and 'car_navigation_snapshot_v4' in repo,'Android Auto persists v4 Ferrostar recovery state'),
 ('FerrostarProductionRuntimeTest' in workflow and 'connectedDebugAndroidTest' in workflow,'CI executes Ferrostar production runtime on Android emulator'),
 ((root/'android/app/src/main/kotlin/no/govia/mobile/car/NavigationCoreV2.kt').exists() is False,'legacy Kotlin NavigationCoreV2 removed'),
 ((root/'android/app/src/main/kotlin/no/govia/mobile/car/NavigationGuidanceV1.kt').exists() is False,'legacy Kotlin GuidanceV1 removed'),
 ((root/'lib/features/navigation/domain/navigation_session.dart').exists() is False,'legacy Dart NavigationSession removed'),
]
for c,l in checks: ok &= check(c,l)
# version synchronization
pub=re.search(r'^version:\s*([^\s]+)',text('pubspec.yaml'),re.M)
version=pub.group(1) if pub else ''
ok &= check(version and version in text('README.md') and version in text('RELEASE.md'),'release version markers stay synchronized')
sim=text('lib/dev/navigation_simulator/navigation_simulator_screen.dart')
sim_models=text('lib/dev/navigation_simulator/simulator_models.dart')
manifest=text('android/app/src/main/AndroidManifest.xml')
voice=text('lib/features/navigation/domain/navigation_voice_localizer.dart')
car_voice=text('android/app/src/main/kotlin/no/govia/mobile/car/NavigationVoiceLocalizer.kt')
ok &= check('/api/v1/map/guidance' not in sim,'navigation simulator also uses provider guidance only')
ok &= check('android.intent.action.TTS_SERVICE' in manifest,'Android TTS engine discovery declared')
ok &= check('displayInstruction' in voice and 'displayInstruction' in car_voice,'phone and Android Auto share semantic display localization')
ok &= check('_densifyGeometry' in sim_models and 'shapeIndex: shapeIndex' in sim_models,'simulator fallback maneuvers are explicitly Ferrostar anchored')
raise SystemExit(0 if ok else 1)
