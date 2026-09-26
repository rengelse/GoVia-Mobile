import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';

class RecordRideScreen extends StatefulWidget { const RecordRideScreen({super.key}); @override State<RecordRideScreen> createState()=>_RecordRideScreenState(); }
class _RecordRideScreenState extends State<RecordRideScreen> {
  bool recording=false; bool paused=false; StreamSubscription<Position>? sub; final points=<Position>[]; DateTime? started;
  @override void dispose(){sub?.cancel();super.dispose();}
  Future<void> _toggle() async {
    if(recording){await sub?.cancel(); setState(()=>recording=false); return;}
    var permission=await Geolocator.checkPermission(); if(permission==LocationPermission.denied) permission=await Geolocator.requestPermission();
    if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Posisjonstillatelse kreves for opptak.')));return;}
    started=DateTime.now(); points.clear(); sub=Geolocator.getPositionStream(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:10)).listen((p){if(!paused&&mounted)setState(()=>points.add(p));}); setState(()=>recording=true);
  }
  @override Widget build(BuildContext context)=>GoViaScreen(title:'Ta opp tur',child:Column(children:[
    RouteMapCard(height:300,label:recording?(paused?'Pauset':'Tar opp'):'Klar'), const SizedBox(height:18),
    Row(children:[MetricCard(label:'GPS-punkter',value:'${points.length}',icon:Icons.gps_fixed,color:GoViaColors.orange),const SizedBox(width:10),MetricCard(label:'Tid',value:started==null?'0:00':_elapsed(),icon:Icons.timer_outlined)]),
    const SizedBox(height:18), if(recording) OutlinedButton.icon(onPressed:()=>setState(()=>paused=!paused),icon:Icon(paused?Icons.play_arrow:Icons.pause),label:Text(paused?'Fortsett':'Pause')), const SizedBox(height:10),
    FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:recording?GoViaColors.red:GoViaColors.orange),onPressed:_toggle,icon:Icon(recording?Icons.stop:Icons.radio_button_checked),label:Text(recording?'Avslutt opptak':'Start opptak')),
    const SizedBox(height:14), const Text('GPS lagres i minnet i denne baseline. Varig batch/komprimert opplasting krever recorded_rides-kontrakten definert i v1-spesifikasjonen.',style:TextStyle(color:GoViaColors.muted)),
  ]));
  String _elapsed(){final d=DateTime.now().difference(started!);return '${d.inHours}:${(d.inMinutes%60).toString().padLeft(2,'0')}';}
}
