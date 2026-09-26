import 'package:flutter/material.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/screen_scaffold.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override Widget build(BuildContext context)=>GoViaScreen(title:'Varsler',child:Column(children:const[
    _Notice(icon:Icons.route,color:GoViaColors.orange,title:'Ruten er oppdatert',text:'Dag 2 har fått ny offisiell rute.',time:'12 min'),
    _Notice(icon:Icons.group_add_outlined,color:GoViaColors.blue,title:'Ny deltaker',text:'Marius ble med på turen.',time:'1 t'),
    _Notice(icon:Icons.cloud_outlined,color:GoViaColors.cyan,title:'Vær langs ruten',text:'Økende vind etter kl. 17.',time:'2 t'),
    _Notice(icon:Icons.download_done_outlined,color:GoViaColors.green,title:'Offlinepakke klar',text:'Norge → Danmark er tilgjengelig offline.',time:'I går'),
  ]));
}
class _Notice extends StatelessWidget{const _Notice({required this.icon,required this.color,required this.title,required this.text,required this.time});final IconData icon;final Color color;final String title,text,time;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:ListTile(leading:CircleAvatar(backgroundColor:color.withValues(alpha:.12),child:Icon(icon,color:color)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(text),trailing:Text(time,style:const TextStyle(color:GoViaColors.muted,fontSize:12)))));}
