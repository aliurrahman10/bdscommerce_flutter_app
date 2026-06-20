import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';

class DeliveryChargesPage extends StatefulWidget {
  const DeliveryChargesPage({super.key});

  @override
  State<DeliveryChargesPage> createState() => _DeliveryChargesPageState();
}

class _DeliveryChargesPageState extends State<DeliveryChargesPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() => context.read<WorkspaceController>().storeApi.deliveryCharges(context.read<WorkspaceController>().activeStoreToken!);
  void _refresh() => setState(() => _future = _load());

  Future<void> _form({Map<String, dynamic>? item}) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final amount = TextEditingController(text: item?['amount']?.toString() ?? '0');
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => AlertDialog(
      title: Text(item == null ? 'Add delivery charge' : 'Edit delivery charge'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'name': name.text.trim(), 'amount': amount.text.trim()}), child: const Text('Save'))],
    ));
    if (result == null || result['name']!.isEmpty) return;
    try {
      final workspace = context.read<WorkspaceController>();
      if (item == null) {
        await workspace.storeApi.createDeliveryCharge(workspace.activeStoreToken!, result);
      } else {
        await workspace.storeApi.updateDeliveryCharge(workspace.activeStoreToken!, int.parse(item['id'].toString()), result);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery charge saved.')));
      _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete delivery charge?'), content: Text('Delete ${item['name']}?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.deleteDeliveryCharge(workspace.activeStoreToken!, int.parse(item['id'].toString()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery charge deleted.')));
      _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Charges')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _form(), icon: const Icon(Icons.add), label: const Text('Add')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          if (items.isEmpty) return const Center(child: Text('No delivery charge found.'));
          return ListView.builder(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), itemCount: items.length, itemBuilder: (_, i) {
            final item = items[i];
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
              title: Text(item['name']?.toString() ?? 'Delivery', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Amount: ৳ ${item['amount'] ?? 0}'),
              trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _form(item: item); if (v == 'delete') _delete(item); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]),
              onTap: () => _form(item: item),
            ));
          });
        },
      ),
    );
  }
}
