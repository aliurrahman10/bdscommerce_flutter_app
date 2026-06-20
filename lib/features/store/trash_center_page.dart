import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class TrashCenterPage extends StatefulWidget {
  const TrashCenterPage({super.key});

  @override
  State<TrashCenterPage> createState() => _TrashCenterPageState();
}

class _TrashCenterPageState extends State<TrashCenterPage> {
  late Future<Map<String, dynamic>> _summaryFuture;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<Map<String, dynamic>> _loadSummary() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.trashSummary(workspace.activeStoreToken!);
  }

  void _refreshSummary() {
    final next = _loadSummary();
    setState(() => _summaryFuture = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trash Center'), actions: [IconButton(onPressed: _refreshSummary, icon: const Icon(Icons.refresh))]),
      body: Column(
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
              final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Safe trash flow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('Trash hides unwanted orders/products from normal app lists. Restore is safe. Permanent delete is only for cleanup and needs confirmation.', style: TextStyle(color: AppTheme.muted)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _Metric(label: 'Orders', value: summary['trashed_orders'] ?? 0)),
                            const SizedBox(width: 8),
                            Expanded(child: _Metric(label: 'Products', value: summary['trashed_products'] ?? 0)),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            _Chip(text: features['orders'] == false ? 'Orders locked by package' : 'Orders sync ok'),
                            _Chip(text: features['products'] == false ? 'Products locked by package' : 'Products sync ok'),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 0, icon: Icon(Icons.receipt_long_outlined), label: Text('Orders')),
                        ButtonSegment<int>(value: 1, icon: Icon(Icons.inventory_2_outlined), label: Text('Products')),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (values) => setState(() => _tab = values.first),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(child: _tab == 0 ? _TrashedOrders(onChanged: _refreshSummary) : _TrashedProducts(onChanged: _refreshSummary)),
        ],
      ),
    );
  }
}

class _TrashedOrders extends StatefulWidget {
  const _TrashedOrders({required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<_TrashedOrders> createState() => _TrashedOrdersState();
}

class _TrashedOrdersState extends State<_TrashedOrders> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.trashedOrders(workspace.activeStoreToken!, search: _search.text);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
    widget.onChanged();
  }

  Future<void> _restore(int id) async {
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.restoreTrashedOrder(workspace.activeStoreToken!, id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Order restored.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(int id) async {
    final ok = await _confirm(context, 'Permanently delete order?', 'This will remove the order and its items. Reports may change. This action cannot be undone.');
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.permanentlyDeleteOrder(workspace.activeStoreToken!, id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Order deleted.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(controller: _search, textInputAction: TextInputAction.search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search trashed order'), onSubmitted: (_) => _refresh()),
      ),
      Expanded(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final items = snapshot.data?['data'] as List<dynamic>? ?? [];
            if (items.isEmpty) return const Center(child: Text('No trashed order found.'));
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final order = items[index] as Map<String, dynamic>;
                  final id = int.parse(order['id'].toString());
                  final statusText = order['order_status']?['name']?.toString() ?? order['status']?.toString() ?? 'N/A';
                  return Card(child: ListTile(
                    title: Text('#$id • ${order['customer_name'] ?? 'Customer'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${order['mobile'] ?? ''}\n$statusText • ৳ ${order['total'] ?? 0}'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => value == 'restore' ? _restore(id) : _delete(id),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'restore', child: Text('Restore')),
                        PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                      ],
                    ),
                  ));
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _TrashedProducts extends StatefulWidget {
  const _TrashedProducts({required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<_TrashedProducts> createState() => _TrashedProductsState();
}

class _TrashedProductsState extends State<_TrashedProducts> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.trashedProducts(workspace.activeStoreToken!, search: _search.text);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
    widget.onChanged();
  }

  Future<void> _restore(int id) async {
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.restoreTrashedProduct(workspace.activeStoreToken!, id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Product restored.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(int id) async {
    final ok = await _confirm(context, 'Permanently delete product?', 'Only products without order history can be permanently deleted. Existing order history will be protected.');
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.permanentlyDeleteProduct(workspace.activeStoreToken!, id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Product deleted.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(controller: _search, textInputAction: TextInputAction.search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search trashed product'), onSubmitted: (_) => _refresh()),
      ),
      Expanded(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final items = snapshot.data?['data'] as List<dynamic>? ?? [];
            if (items.isEmpty) return const Center(child: Text('No trashed product found.'));
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final product = items[index] as Map<String, dynamic>;
                  final id = int.parse(product['id'].toString());
                  final image = product['thumbnail_url']?.toString();
                  return Card(child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFFEAF0F2),
                        child: image == null || image.isEmpty ? const Icon(Icons.inventory_2_outlined) : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined)),
                      ),
                    ),
                    title: Text(product['name']?.toString() ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('Stock: ${product['stock_qty'] ?? 0} • ৳ ${product['display_price'] ?? product['regular_price'] ?? 0}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => value == 'restore' ? _restore(id) : _delete(id),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'restore', child: Text('Restore')),
                        PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                      ],
                    ),
                  ));
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final Object value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFEAF0F2), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

Future<bool?> _confirm(BuildContext context, String title, String message) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
      ],
    ),
  );
}
