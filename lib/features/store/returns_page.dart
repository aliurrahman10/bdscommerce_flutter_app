import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});
  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  late Future<Map<String, dynamic>> _future;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.returns(workspace.activeStoreToken!, status: _status);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _create() async {
    final orderIdCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Return'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: orderIdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order ID')),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 8),
            const Text('First item of this order will be added as good return with qty 1. Details screen theke receive kora jabe.'),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
      ),
    );
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final orderId = int.parse(orderIdCtrl.text.trim());
      final orderRes = await workspace.storeApi.showOrder(token, orderId);
      final order = orderRes['order'] as Map<String, dynamic>;
      final items = (order['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      if (items.isEmpty) throw Exception('No order item found.');
      await workspace.storeApi.createReturn(token, {
        'order_id': orderId,
        'notes': noteCtrl.text.trim(),
        'items': [
          {'order_item_id': int.parse(items.first['id'].toString()), 'qty': 1, 'condition': 'good'}
        ],
      });
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return request created.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Returns / Refunds'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Return')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const ['all', 'requested', 'approved', 'rejected', 'received'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) {
              setState(() => _status = v ?? 'all');
              _refresh();
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
              final rows = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
              if (rows.isEmpty) return const Center(child: Text('No return request found.'));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  return Card(
                    child: ListTile(
                      title: Text('Return #${r['id']} • Order #${r['order_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${r['customer_name'] ?? ''}\nStatus: ${r['status']}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReturnDetailPage(returnId: int.parse(r['id'].toString())))).then((_) => _refresh()),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class ReturnDetailPage extends StatefulWidget {
  const ReturnDetailPage({super.key, required this.returnId});
  final int returnId;
  @override
  State<ReturnDetailPage> createState() => _ReturnDetailPageState();
}

class _ReturnDetailPageState extends State<ReturnDetailPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() => context.read<WorkspaceController>().storeApi.showReturn(context.read<WorkspaceController>().activeStoreToken!, widget.returnId);
  void _refresh() { final next = _load(); setState(() { _future = next; }); }
  Future<void> _status(String status) async { try { final w=context.read<WorkspaceController>(); await w.storeApi.updateReturnStatus(w.activeStoreToken!, widget.returnId, status); _refresh(); } catch(e){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); } }
  Future<void> _receive() async { try { final w=context.read<WorkspaceController>(); await w.storeApi.receiveReturn(w.activeStoreToken!, widget.returnId); _refresh(); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Return received.'))); } catch(e){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); } }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Return #${widget.returnId}')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text(s.error.toString()));
            final r = s.data?['return'] as Map<String, dynamic>? ?? {};
            final items = (r['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            final received = r['status'] == 'received';
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: ListTile(title: Text('Order #${r['order_id']}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${r['customer_name'] ?? ''}\nStatus: ${r['status']}'), isThreeLine: true)),
              const SizedBox(height: 12),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ...items.map((it) => Card(child: ListTile(title: Text(it['product_name']?.toString() ?? 'Product'), subtitle: Text('Qty: ${it['qty']} • Condition: ${it['condition']}')))),
              const SizedBox(height: 14),
              if (!received) Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonal(onPressed: () => _status('approved'), child: const Text('Approve')),
                FilledButton.tonal(onPressed: () => _status('rejected'), child: const Text('Reject')),
                FilledButton.icon(onPressed: _receive, icon: const Icon(Icons.inventory_2_outlined), label: const Text('Receive & Restock')),
              ]),
            ]);
          },
        ),
      );
}
