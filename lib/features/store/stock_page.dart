import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late Future<Map<String, dynamic>> _future;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.inventoryStock(workspace.activeStoreToken!, search: _search.text);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _adjust() async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    final productsRes = await workspace.storeApi.products(token, perPage: 100);
    final warehousesRes = await workspace.storeApi.warehouses(token);
    final products = (productsRes['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final warehouses = (warehousesRes['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (products.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product required first.')));
      return;
    }

    int productId = int.parse(products.first['id'].toString());
    int? warehouseId = warehouses.isEmpty ? null : int.parse(warehouses.first['id'].toString());
    final qty = TextEditingController(text: '1');
    final note = TextEditingController(text: 'Mobile stock adjustment');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Adjust Stock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: products.map((p) => DropdownMenuItem<int>(value: int.parse(p['id'].toString()), child: Text(p['name']?.toString() ?? 'Product'))).toList(),
                  onChanged: (v) => setLocal(() => productId = v ?? productId),
                ),
                const SizedBox(height: 8),
                if (warehouses.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: warehouseId,
                    decoration: const InputDecoration(labelText: 'Warehouse'),
                    items: warehouses.map((w) => DropdownMenuItem<int>(value: int.parse(w['id'].toString()), child: Text(w['name']?.toString() ?? 'Warehouse'))).toList(),
                    onChanged: (v) => setLocal(() => warehouseId = v),
                  ),
                const SizedBox(height: 8),
                TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty (+ increase, - decrease)')),
                const SizedBox(height: 8),
                TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      await workspace.storeApi.adjustStock(token, {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'qty': int.tryParse(qty.text.trim()) ?? 0,
        'note': note.text.trim(),
      });
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock adjusted.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _movements(Map<String, dynamic> item) async {
    final workspace = context.read<WorkspaceController>();
    final res = await workspace.storeApi.inventoryMovements(workspace.activeStoreToken!, inventoryItemId: int.parse(item['id'].toString()));
    final rows = (res['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(item['product_name']?.toString() ?? 'Stock movements', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          if (rows.isEmpty) const Text('No movement found.'),
          ...rows.map((m) => ListTile(title: Text('${m['type']} • Qty ${m['qty']}'), subtitle: Text('${m['note'] ?? ''}\n${m['created_at'] ?? ''}'), isThreeLine: true)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _adjust, icon: const Icon(Icons.add), label: const Text('Adjust')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search product or SKU'), onSubmitted: (_) => _refresh()),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                final rows = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                if (rows.isEmpty) return const Center(child: Text('No stock item found.'));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final item = rows[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(.12), foregroundColor: AppTheme.primary, child: const Icon(Icons.inventory_2_outlined)),
                        title: Text(item['product_name']?.toString() ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item['warehouse_name'] ?? ''}\nSKU: ${item['sku'] ?? '-'}'),
                        isThreeLine: true,
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(item['on_hand'].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const Text('on hand')]),
                        onTap: () => _movements(item),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
