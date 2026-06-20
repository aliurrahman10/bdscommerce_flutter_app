import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'products_page.dart';
import 'suppliers_page.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    final purchases = await workspace.storeApi.purchases(token);
    final suppliers = await workspace.storeApi.suppliers(token, perPage: 100);
    return {'purchases': purchases, 'suppliers': suppliers};
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<bool> _confirmDependency({required String title, required String message, required String action}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _createPurchase(List<Map<String, dynamic>> suppliers) async {
    if (suppliers.isEmpty) {
      final go = await _confirmDependency(
        title: 'Supplier required',
        message: 'Purchase order create korar age at least one supplier create korte hobe.',
        action: 'Add Supplier',
      );
      if (go && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuppliersPage()));
        _refresh();
      }
      return;
    }

    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    Map<String, dynamic> productsRes;
    try {
      productsRes = await workspace.storeApi.products(token, perPage: 100);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    final products = (productsRes['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (products.isEmpty) {
      final go = await _confirmDependency(
        title: 'Product required',
        message: 'Purchase order er jonno at least one product create korte hobe.',
        action: 'Go Products',
      );
      if (go && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductsPage()));
        _refresh();
      }
      return;
    }

    int supplierId = int.parse(suppliers.first['id'].toString());
    int productId = int.parse(products.first['id'].toString());
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: '0');
    final expectedCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create Purchase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: suppliers.map((supplier) => DropdownMenuItem<int>(value: int.parse(supplier['id'].toString()), child: Text(supplier['name'].toString()))).toList(),
                  onChanged: (value) => setLocal(() => supplierId = value ?? supplierId),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: products.map((product) => DropdownMenuItem<int>(value: int.parse(product['id'].toString()), child: Text(product['name']?.toString() ?? 'Product'))).toList(),
                  onChanged: (value) => setLocal(() => productId = value ?? productId),
                ),
                const SizedBox(height: 8),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty')),
                const SizedBox(height: 8),
                TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost')),
                const SizedBox(height: 8),
                TextField(controller: expectedCtrl, decoration: const InputDecoration(labelText: 'Expected date YYYY-MM-DD')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    try {
      await workspace.storeApi.createPurchase(token, {
        'supplier_id': supplierId,
        'expected_at': expectedCtrl.text.trim().isEmpty ? null : expectedCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
        'items': [
          {'product_id': productId, 'qty': int.tryParse(qtyCtrl.text.trim()) ?? 1, 'cost': costCtrl.text.trim()}
        ],
      });
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase order created.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchases'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final suppliersMap = snapshot.data?['suppliers'] as Map<String, dynamic>? ?? {};
          final suppliers = (suppliersMap['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return FloatingActionButton.extended(
            onPressed: () => _createPurchase(suppliers),
            icon: const Icon(Icons.add),
            label: const Text('Purchase'),
          );
        },
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));

          final purchasesMap = snapshot.data?['purchases'] as Map<String, dynamic>? ?? {};
          final suppliersMap = snapshot.data?['suppliers'] as Map<String, dynamic>? ?? {};
          final purchases = (purchasesMap['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final suppliers = (suppliersMap['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(Icons.account_tree_outlined, color: AppTheme.primary),
                  title: const Text('Dependency: Supplier + Product', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Suppliers available: ${suppliers.length}. Product list theke product select korte hobe.'),
                ),
              ),
              if (suppliers.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: const Text('Supplier missing', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Purchase create korar age supplier add koro.'),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuppliersPage()));
                        _refresh();
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (purchases.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No purchase order found.'))),
              ...purchases.map((purchase) => Card(
                    child: ListTile(
                      title: Text('${purchase['po_number']} • ${purchase['supplier_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Status: ${purchase['status']} • Expected: ${purchase['expected_at'] ?? 'N/A'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => PurchaseDetailPage(purchaseId: int.parse(purchase['id'].toString()))))
                          .then((_) => _refresh()),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class PurchaseDetailPage extends StatefulWidget {
  const PurchaseDetailPage({super.key, required this.purchaseId});

  final int purchaseId;

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  late Future<Map<String, dynamic>> _future;
  final Map<int, TextEditingController> _receiveCtrls = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.showPurchase(workspace.activeStoreToken!, widget.purchaseId);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _receive(List<Map<String, dynamic>> items) async {
    final receive = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = int.parse(item['id'].toString());
      final qty = int.tryParse(_receiveCtrls[id]?.text.trim() ?? '0') ?? 0;
      receive.add({'id': id, 'qty': qty});
    }

    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.receivePurchase(workspace.activeStoreToken!, widget.purchaseId, receive);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receiving saved.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Purchase #${widget.purchaseId}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));

          final purchase = snapshot.data?['purchase'] as Map<String, dynamic>? ?? {};
          final items = (purchase['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(purchase['po_number']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${purchase['supplier_name'] ?? ''}\nStatus: ${purchase['status']}'),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 10),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ...items.map((item) {
                final id = int.parse(item['id'].toString());
                _receiveCtrls.putIfAbsent(id, () => TextEditingController(text: item['remaining_qty']?.toString() ?? '0'));
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['product_name']?.toString() ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Qty: ${item['qty']} • Received: ${item['received_qty']} • Remaining: ${item['remaining_qty']}'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _receiveCtrls[id],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Receive qty'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => _receive(items), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Save Receiving')),
            ],
          );
        },
      ),
    );
  }
}
