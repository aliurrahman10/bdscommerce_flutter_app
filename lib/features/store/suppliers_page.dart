import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});
  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() => context.read<WorkspaceController>().storeApi.suppliers(context.read<WorkspaceController>().activeStoreToken!);
  void _refresh() { final f = _load(); setState(() => _future = f); }

  Future<void> _openForm([Map<String, dynamic>? supplier]) async {
    final name = TextEditingController(text: supplier?['name']?.toString() ?? '');
    final phone = TextEditingController(text: supplier?['phone']?.toString() ?? '');
    final email = TextEditingController(text: supplier?['email']?.toString() ?? '');
    final address = TextEditingController(text: supplier?['address']?.toString() ?? '');
    bool status = supplier?['status'] != false;
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: Text(supplier == null ? 'Add Supplier' : 'Edit Supplier'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 8),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 8),
        TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 8),
        TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
        SwitchListTile(value: status, onChanged: (v) => setLocal(() => status = v), title: const Text('Active')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    if (ok != true) return;
    try {
      final api = context.read<WorkspaceController>().storeApi;
      final token = context.read<WorkspaceController>().activeStoreToken!;
      final data = {'name': name.text.trim(), 'phone': phone.text.trim(), 'email': email.text.trim(), 'address': address.text.trim(), 'status': status};
      if (supplier == null) { await api.createSupplier(token, data); } else { await api.updateSupplier(token, int.parse(supplier['id'].toString()), data); }
      _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _delete(Map<String, dynamic> supplier) async {
    try { final w = context.read<WorkspaceController>(); await w.storeApi.deleteSupplier(w.activeStoreToken!, int.parse(supplier['id'].toString())); _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Suppliers'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Add')),
    body: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
      final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      if (items.isEmpty) return const Center(child: Text('No supplier found.'));
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, i) { final s = items[i]; return Card(child: ListTile(
        title: Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${s['phone'] ?? ''}\n${s['email'] ?? ''}'), isThreeLine: true,
        trailing: PopupMenuButton<String>(onSelected: (v) => v == 'edit' ? _openForm(s) : _delete(s), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]),
      )); });
    }),
  );
}
