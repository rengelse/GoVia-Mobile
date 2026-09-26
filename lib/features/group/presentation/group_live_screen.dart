import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';

class GroupLiveScreen extends StatelessWidget {
  const GroupLiveScreen({super.key,this.embedded=false}); final bool embedded;
  @override Widget build(BuildContext context){final trip=AppScope.of(context).activeTrip; final body=ListView(padding:EdgeInsets.fromLTRB(18,embedded?18:8,18,110),children:[
    if(embedded)...[Text('Gruppe live',style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:6),const Text('Følg reisefølget under aktiv tur.',style:TextStyle(color:GoViaColors.muted)),const SizedBox(height:16)],
    const RouteMapCard(height:330,showRiders:true,label:'Live-posisjoner'), const SizedBox(height:16),
    Row(children:[Expanded(child:FilledButton.icon(onPressed:()=>Navigator.pushNamed(context,AppRoutes.chat),icon:const Icon(Icons.chat_bubble_outline),label:const Text('Chat'))),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:()=>Navigator.pushNamed(context,AppRoutes.participants),icon:const Icon(Icons.groups_2_outlined),label:const Text('Deltakere')))]),
    const SizedBox(height:20), const SectionTitle('Reisefølge'),
    for(final p in trip?.participants??const[]) Card(child:ListTile(leading:CircleAvatar(backgroundColor:p.online?GoViaColors.cyan:GoViaColors.border,child:Text(p.name.substring(0,1))),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(p.role=='owner'?'Tureier':'Deltaker'),trailing:StatusPill(p.online?'Live':'Offline',color:p.online?GoViaColors.green:GoViaColors.muted))),
    const SizedBox(height:12), const Text('Live GPS krever den dedikerte mobile presence-kontrakten før posisjoner sendes til server. Ingen skjult sporing skjer i denne baseline.',style:TextStyle(color:GoViaColors.muted)),
  ]); return embedded?body:Scaffold(appBar:AppBar(title:const Text('Gruppe live')),body:body);}
}
