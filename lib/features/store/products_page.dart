import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'product_detail_page.dart';
import 'product_form_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  String _status = 'all';
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.products(
      workspace.activeStoreToken!,
      search: _searchController.text,
      status: _status == 'all' ? null : _status,
    );
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductFormPage()));
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(hintText: 'Search product or SKU', prefixIcon: Icon(Icons.search)),
                    onSubmitted: (_) => _refresh(),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem<String>(value: 'all', child: Text('All')),
                    DropdownMenuItem<String>(value: '1', child: Text('Active')),
                    DropdownMenuItem<String>(value: '0', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                    _refresh();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                final items = (snapshot.data?['data'] as List<dynamic>? ?? []);
                if (items.isEmpty) return const Center(child: Text('No products found.'));
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final product = items[index] as Map<String, dynamic>;
                      return _ProductCard(product: product, onUpdated: _refresh);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({required this.product, required this.onUpdated});
  final Map<String, dynamic> product;
  final VoidCallback onUpdated;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _updating = false;

  Future<void> _toggleStatus() async {
    setState(() => _updating = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final active = widget.product['status'] == true;
      await workspace.storeApi.quickUpdateProduct(
        token: workspace.activeStoreToken!,
        productId: int.parse(widget.product['id'].toString()),
        status: !active,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product status updated.')));
      widget.onUpdated();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _moveToTrash() async {
    final id = int.tryParse(widget.product['id']?.toString() ?? '');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move product to trash?'),
        content: const Text('This product will be hidden from website and normal product list. You can restore it from Trash Center.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move to trash')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _updating = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.trashProduct(workspace.activeStoreToken!, id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Product moved to trash.')));
      widget.onUpdated();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final active = product['status'] == true;
    final inStock = product['in_stock'] == true;
    final image = product['thumbnail_url']?.toString();
    final categories = (product['categories'] as List<dynamic>? ?? []).map((e) => (e as Map)['name']).join(', ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(productId: int.parse(product['id'].toString()))));
          widget.onUpdated();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 66,
                  height: 66,
                  color: const Color(0xFFEAF0F2),
                  child: image == null || image.isEmpty
                      ? const Icon(Icons.inventory_2_outlined, color: AppTheme.primary)
                      : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product['name']?.toString() ?? 'Product', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(categories.isEmpty ? 'No category' : categories, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Chip(text: '৳ ${product['display_price'] ?? product['regular_price'] ?? '0'}'),
                    _Chip(text: 'Stock: ${product['stock_qty'] ?? 0}', color: inStock ? const Color(0xFFE8F6EE) : const Color(0xFFFFECEC)),
                    _Chip(text: active ? 'Active' : 'Inactive', color: active ? const Color(0xFFE8F6EE) : const Color(0xFFFFF3D9)),
                  ]),
                ]),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: active ? 'Make inactive' : 'Make active',
                  onPressed: _updating ? null : _toggleStatus,
                  icon: Icon(active ? Icons.toggle_on : Icons.toggle_off, color: active ? AppTheme.primary : Colors.grey, size: 34),
                ),
                PopupMenuButton<String>(
                  enabled: !_updating,
                  onSelected: (value) {
                    if (value == 'trash') _moveToTrash();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'trash', child: Text('Move to Trash'))],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color ?? const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
