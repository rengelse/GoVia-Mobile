import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});
  @override Widget build(BuildContext context){final weather=AppScope.of(context).weather;return GoViaScreen(title:'Vær',subtitle:'Langs dagens rute',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const RouteMapCard(height:230,label:'Vær langs ruten'),const SizedBox(height:16),
    if(weather.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Ingen værdata lastet. Produksjonsdata hentes fra /api/v1/weather/route.')))
    else SizedBox(height:124,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:weather.length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(context,i){final w=weather[i];return Container(width:112,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:GoViaColors.panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:GoViaColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(w.label,style:const TextStyle(color:GoViaColors.muted)),const SizedBox(height:8),const Icon(Icons.cloud_outlined,color:GoViaColors.blue),const Spacer(),Text('${w.temperature.round()}°',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('${w.wind.round()} m/s',style:const TextStyle(color:GoViaColors.muted,fontSize:12))]));})),
    const SizedBox(height:20),const SectionTitle('Ruteinnsikt'),const Card(child:Padding(padding:EdgeInsets.all(18),child:Row(children:[Icon(Icons.umbrella_outlined,color:GoViaColors.blue),SizedBox(width:12),Expanded(child:Text('Værdata cache-es lokalt med tidsstempel. Offline-data skal alltid merkes som sist oppdatert, aldri fremstilles som live.'))]))),
  ]));}
}
