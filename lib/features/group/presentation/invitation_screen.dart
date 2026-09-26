import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/screen_scaffold.dart';

class InvitationScreen extends StatefulWidget { const InvitationScreen({super.key}); @override State<InvitationScreen> createState()=>_InvitationScreenState(); }
class _InvitationScreenState extends State<InvitationScreen> {
  bool scanning=false; String? value;
  @override Widget build(BuildContext context)=>GoViaScreen(title:'Hent fra Desktop',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Skann QR-koden fra GoVia Desktop. Koden skal bare inneholde en kortlivet single-use handoff-token – aldri JWT, API-nøkler eller hele turen.',style:TextStyle(color:GoViaColors.muted)), const SizedBox(height:18),
    if(scanning) ClipRRect(borderRadius:BorderRadius.circular(20),child:SizedBox(height:360,child:MobileScanner(onDetect:(capture){final code=capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;if(code!=null&&mounted)setState((){value=code;scanning=false;});}))) else Container(height:260,decoration:BoxDecoration(color:GoViaColors.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:GoViaColors.border)),child:Center(child:Icon(Icons.qr_code_2_rounded,size:130,color:value==null?GoViaColors.muted:GoViaColors.orange))),
    const SizedBox(height:16), FilledButton.icon(onPressed:()=>setState(()=>scanning=!scanning),icon:Icon(scanning?Icons.close:Icons.qr_code_scanner),label:Text(scanning?'Stopp skanning':'Skann QR-kode')),
    if(value!=null)...[const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Kode lest',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(value!,maxLines:2,overflow:TextOverflow.ellipsis),const SizedBox(height:10),const Text('Consume-endpoint for sikker Desktop → Mobile handoff må legges til i GoVia API før turen kan hentes.',style:TextStyle(color:GoViaColors.muted))])))],
  ]));
}
