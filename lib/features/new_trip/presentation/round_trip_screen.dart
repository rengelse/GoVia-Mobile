import 'package:flutter/material.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/route_profile_picker.dart';

class RoundTripScreen extends StatefulWidget { const RoundTripScreen({super.key}); @override State<RoundTripScreen> createState()=>_RoundTripScreenState(); }
class _RoundTripScreenState extends State<RoundTripScreen> {
  double km=180; String direction='Fri'; String profile='Raskest'; bool avoidMotorway=true;
  @override Widget build(BuildContext context)=>GoViaScreen(title:'Opprett rundtur', child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const RouteMapCard(height:250,label:'Rundtur'), const SizedBox(height:18),
    Text('Ønsket lengde: ${km.round()} km',style:const TextStyle(fontWeight:FontWeight.w800)), Slider(value:km,min:40,max:600,divisions:56,label:'${km.round()} km',onChanged:(v)=>setState(()=>km=v)),
    DropdownButtonFormField(initialValue:direction,decoration:const InputDecoration(labelText:'Retning'),items:const ['Fri','Nord','Sør','Øst','Vest','Tilfeldig'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>direction=v??direction)), const SizedBox(height:10),
    RouteProfilePicker(value: profile, enabledProfiles: const {'Raskest'}, onChanged: (v) => setState(() => profile = v)),
    SwitchListTile(contentPadding:EdgeInsets.zero,value:avoidMotorway,onChanged:(v)=>setState(()=>avoidMotorway=v),title:const Text('Unngå motorvei')),
    const SizedBox(height:12), FilledButton.icon(onPressed:(){showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('Backendkontrakt mangler'),content:const Text('Roundtrip-generatoren er ferdig definert i Mobile v1, men v0.86.178 har ennå ikke et roundtrip-endpoint. UI-et sender ikke oppdiktede ruter.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('OK'))]));},icon:const Icon(Icons.loop),label:const Text('Generer rundtur')),
    const SizedBox(height:12), const Text('GoVia skal generere 1–3 kandidater når serverens roundtrip-kontrakt er implementert.',style:TextStyle(color:GoViaColors.muted)),
  ]));
}
