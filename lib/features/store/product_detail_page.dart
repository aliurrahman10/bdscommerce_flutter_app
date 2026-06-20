import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'product_form_page.dart';
import 'product_variations_page.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<Map<String, dynamic>> _future;
  final _stockController = TextEditingController();
  final _regularPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  bool _active = true;
  bool _inStock = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _stockController.dispose();
    _regularPriceController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.showProduct(workspace.activeStoreToken!, widget.productId);
  }

  void _fill(Map<String, dynamic> product) {
    if (_loaded) return;
    _loaded = true;
    _stockController.text = product['stock_qty']?.toString() ?? '0';
    _regularPriceController.text = product['regular_price']?.toString() ?? '';
    _salePriceController.text = product['sale_price']?.toString() ?? '';
    _active = product['status'] == true;
    _inStock = product['in_stock'] == true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.quickUpdateProduct(
        token: workspace.activeStoreToken!,
        productId: widget.productId,
        stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
        status: _active,
        inStock: _inStock,
        regularPrice: _regularPriceController.text,
        salePrice: _salePriceController.text,
      );
      _loaded = false;
      setState(() {
        _future = _load();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            tooltip: 'Variations',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductVariationsPage(productId: widget.productId))),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Edit product',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductFormPage(productId: widget.productId)));
              _loaded = false;
              setState(() {
                _future = _load();
              });
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final product = snapshot.data?['product'] as Map<String, dynamic>? ?? {};
          _fill(product);
          final image = product['thumbnail_url']?.toString();
          final cats = (product['categories'] as List<dynamic>? ?? []).map((e) => (e as Map)['name']).join(', ');
          final variations = product['variations'] as List<dynamic>? ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 190,
                  color: const Color(0xFFEAF0F2),
                  child: image == null || image.isEmpty
                      ? const Center(child: Icon(Icons.inventory_2_outlined, size: 54, color: AppTheme.primary))
                      : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.inventory_2_outlined))),
                ),
              ),
              const SizedBox(height: 12),
              if ((product['gallery_urls'] as List<dynamic>? ?? []).isNotEmpty) SizedBox(
                height: 82,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: (product['gallery_urls'] as List<dynamic>? ?? []).map((url) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url.toString(), width: 82, height: 82, fit: BoxFit.cover)),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Text(product['name']?.toString() ?? 'Product', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                if (product['product_type']?.toString() == 'variable') const Chip(label: Text('Variable')),
              ]),
              const SizedBox(height: 6),
              Text(cats.isEmpty ? 'No category selected' : cats, style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _regularPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Regular price'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: _salePriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sale price'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock quantity')),
                      const SizedBox(height: 10),
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Product active'), value: _active, onChanged: (v) => setState(() => _active = v)),
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In stock'), value: _inStock, onChanged: (v) => setState(() => _inStock = v)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                          label: Text(_saving ? 'Saving...' : 'Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if ((product['short_description']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(product['short_description'].toString()))),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductVariationsPage(productId: widget.productId))),
                icon: const Icon(Icons.tune),
                label: const Text('Manage variations'),
              ),
              if (variations.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Variations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ...variations.map((raw) {
                  final v = raw as Map<String, dynamic>;
                  return Card(child: ListTile(title: Text(v['variation_name']?.toString() ?? v['sku']?.toString() ?? 'Variation'), subtitle: Text('Stock: ${v['stock_qty'] ?? 0}'), trailing: Text(v['price']?.toString() ?? '')));
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}
