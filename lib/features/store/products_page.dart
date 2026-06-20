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
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductFormPage()));
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      filled: true, fillColor: AppTheme.primary.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.muted),
                      hintText: 'Search product...',
                    ),
                    onSubmitted: (_) => _refresh(),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusFilter(value: _status, onChanged: (v) { setState(() => _status = v); _refresh(); }),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
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
      await workspace.storeApi.quickUpdateProduct(token: workspace.activeStoreToken!, productId: int.parse(widget.product['id'].toString()), status: !active);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product status updated.')));
      widget.onUpdated();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final active = p['status'] == true;
    final inStock = p['in_stock'] == true;
    final image = p['thumbnail_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(productId: int.parse(p['id'].toString()))));
            widget.onUpdated();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60, height: 60, color: const Color(0xFFF1F5F9),
                    child: image == null || image.isEmpty ? const Icon(Icons.inventory_2_outlined, color: AppTheme.muted) : Image.network(image, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name']?.toString() ?? 'Product', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _Chip(text: '৳ ${p['display_price'] ?? p['regular_price'] ?? '0'}', bgColor: AppTheme.primary.withOpacity(0.08), textColor: AppTheme.primary),
                        _Chip(text: inStock ? 'In Stock' : 'Out of Stock', bgColor: inStock ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), textColor: inStock ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _updating ? null : _toggleStatus,
                  icon: Icon(active ? Icons.toggle_on : Icons.toggle_off, color: active ? AppTheme.primary : AppTheme.muted, size: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All')),
            DropdownMenuItem(value: '1', child: Text('Active')),
            DropdownMenuItem(value: '0', child: Text('Inactive')),
          ],
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.bgColor, this.textColor});
  final String text;
  final Color? bgColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor ?? const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor ?? AppTheme.text)),
    );
  }
}