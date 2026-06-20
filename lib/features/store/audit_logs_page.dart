import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});
  @override State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  late Future<Map<String, dynamic>> _future;
  String _module = 'all';
  @override void initState(){super.initState();_future=_load();}
  Future<Map<String,dynamic>> _load(){final w=context.read<WorkspaceController>();return w.storeApi.auditLogs(w.activeStoreToken!, module:_module);} 
  void _refresh(){final next=_load();setState((){_future=next;});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Activity / Audit Logs'),actions:[IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),body:Column(children:[Padding(padding:const EdgeInsets.all(12),child:DropdownButtonFormField<String>(value:_module,decoration:const InputDecoration(labelText:'Module filter'),items:const [DropdownMenuItem(value:'all',child:Text('All')),DropdownMenuItem(value:'orders',child:Text('Orders')),DropdownMenuItem(value:'products',child:Text('Products')),DropdownMenuItem(value:'staff',child:Text('Staff')),DropdownMenuItem(value:'inventory',child:Text('Inventory')),DropdownMenuItem(value:'content',child:Text('Content'))],onChanged:(v){_module=v??'all';_refresh();})),Expanded(child:FutureBuilder<Map<String,dynamic>>(future:_future,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator()); if(s.hasError)return Center(child:Text(s.error.toString())); final rows=((s.data?['data']??[]) as List<dynamic>).cast<Map<String,dynamic>>(); if(rows.isEmpty)return const Center(child:Text('No audit logs found.')); return ListView.builder(padding:const EdgeInsets.all(12),itemCount:rows.length,itemBuilder:(context,i){final r=rows[i];final user=r['user'] as Map<String,dynamic>?;return Card(child:ListTile(leading:const Icon(Icons.history_outlined,color:AppTheme.primary),title:Text(r['event']?.toString()??r['route']?.toString()??'Activity',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${user?['name']??'Unknown user'} • ${r['created_at']??''}\n${r['route']??r['url']??''}'),isThreeLine:true,onTap:()=>showDialog<void>(context:context,builder:(_)=>AlertDialog(title:Text(r['event']?.toString()??'Activity'),content:SingleChildScrollView(child:Text('User: ${user?['name']??''}\nRoute: ${r['route']??''}\nURL: ${r['url']??''}\nIP: ${r['ip_address']??''}\nStatus: ${r['status_code']??''}\nPayload: ${r['payload']??''}')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]))));});}))]));
}
