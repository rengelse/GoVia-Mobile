import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/app_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/updater/github_updater.dart';
import '../../../core/widgets/govia_widgets.dart';

class ProfileScreen extends StatefulWidget {const ProfileScreen({super.key,this.embedded=false});final bool embedded;@override State<ProfileScreen> createState()=>_ProfileScreenState();}
class _ProfileScreenState extends State<ProfileScreen>{String version='…';bool checking=false;double? progress;@override void initState(){super.initState();PackageInfo.fromPlatform().then((p){if(mounted)setState(()=>version=p.version);});}
Future<void> _checkUpdate()async{setState(()=>checking=true);try{final updater=GithubUpdater();final info=await updater.check();if(!mounted)return;if(info==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Du har siste versjon.')));return;}final install=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(info.name),content:SingleChildScrollView(child:Text(info.notes.isEmpty?'Ny versjon ${info.version} er tilgjengelig.':info.notes)),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Senere')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Last ned'))]));if(install==true){final file=await updater.download(info,onProgress:(v){if(mounted)setState(()=>progress=v);});await updater.install(file);}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Oppdatering feilet: $e')));}finally{if(mounted)setState((){checking=false;progress=null;});}}
@override Widget build(BuildContext context){final state=AppScope.of(context);final body=ListView(padding:EdgeInsets.fromLTRB(18,widget.embedded?18:8,18,110),children:[
  if(widget.embedded)...[Text('Profil',style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:18)],
  Center(child:Column(children:[const CircleAvatar(radius:44,backgroundColor:GoViaColors.panel2,child:Icon(Icons.person,size:44,color:GoViaColors.cyan)),const SizedBox(height:12),Text(state.auth.user?.email??(AppConfig.devSeed?'Utviklermodus':'Ikke innlogget'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:5),Text('GoVia Mobile v$version',style:const TextStyle(color:GoViaColors.muted))])),
  const SizedBox(height:26),const SectionTitle('Tur og navigasjon'),_tile(Icons.two_wheeler,'Kjøretøy','Motorsykkel'),_tile(Icons.straighten,'Enheter','Metrisk'),_tile(Icons.volume_up_outlined,'Stemme','På'),_tile(Icons.location_on_outlined,'Posisjonsdeling','Kun under aktiv tur'),
  const SizedBox(height:18),const SectionTitle('App'),_tile(Icons.notifications_outlined,'Varsler','Konfigurer'),_tile(Icons.download_for_offline_outlined,'Offlinekart','Administrer'),
  Card(child:ListTile(onTap:Platform.isAndroid&&!checking?_checkUpdate:null,leading:const Icon(Icons.system_update_alt,color:GoViaColors.orange),title:const Text('Se etter oppdatering',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(Platform.isAndroid?'GitHub Releases · v$version':'iOS bruker App Store / TestFlight'),trailing:checking?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.chevron_right))),
  if(progress!=null)...[const SizedBox(height:8),LinearProgressIndicator(value:progress)],
  const SizedBox(height:18),OutlinedButton.icon(onPressed:()async{await state.auth.signOut();if(context.mounted)Navigator.of(context).pushNamedAndRemoveUntil('/login',(r)=>false);},icon:const Icon(Icons.logout),label:const Text('Logg ut')),
]);return widget.embedded?body:Scaffold(appBar:AppBar(title:const Text('Profil / innstillinger')),body:body);}
Widget _tile(IconData icon,String title,String subtitle)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Card(child:ListTile(leading:Icon(icon,color:GoViaColors.blue),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right))));}
