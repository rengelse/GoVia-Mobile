import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';

class PoiScreen extends StatefulWidget {const PoiScreen({super.key});@override State<PoiScreen> createState()=>_PoiScreenState();}
class _PoiScreenState extends State<PoiScreen>{String category='Alle';@override Widget build(BuildContext context){final items=AppScope.of(context).pois.where((p)=>category=='Alle'||p.category==category).toList();return GoViaScreen(title:'Stopp / POI',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const RouteMapCard(height:230,label:'Langs ruten'),const SizedBox(height:14),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:['Alle','Drivstoff','Kaffe','Ferge','Mat','Overnatting','Service'].map((e)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(e),selected:category==e,onSelected:(_)=>setState(()=>category=e)))).toList())),const SizedBox(height:16),
  if(items.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Ingen lokale POI-data. Produksjon bruker /api/v1/map/poi/along.')))
  else for(final p in items) Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:ListTile(leading:const Icon(Icons.place_outlined,color:GoViaColors.orange),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${p.category} · ${(p.distanceMeters/1000).toStringAsFixed(1)} km'),trailing:IconButton(onPressed:(){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${p.name} legges til som stopp når stage-mutation-kontrakten aktiveres.')));},icon:const Icon(Icons.add_circle_outline))))),
]));}}
