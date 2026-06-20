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
      setState(() => _future = _load());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Product Details', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.white, scrolledUnderElevation: 0),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final product = snapshot.data?['product'] as Map<String, dynamic>? ?? {};
          _fill(product);
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProductHero(product: product),
              const SizedBox(height: 16),
              
              _ToolCard(
                icon: Icons.edit_note_rounded,
                title: 'Quick Update',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Input('Regular Price', _regularPriceController)),
                        const SizedBox(width: 12),
                        Expanded(child: _Input('Sale Price', _salePriceController)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Input('Stock Quantity', _stockController),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(title: const Text('Product Active'), value: _active, onChanged: (v) => setState(() => _active = v), contentPadding: EdgeInsets.zero),
                    SwitchListTile.adaptive(title: const Text('In Stock'), value: _inStock, onChanged: (v) => setState(() => _inStock = v), contentPadding: EdgeInsets.zero),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving...' : 'Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ActionsCard(productId: widget.productId, onRefresh: () => setState(() => _future = _load())),
            ],
          );
        },
      ),
    );
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.product});
  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final image = product['thumbnail_url']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(width: 80, height: 80, color: const Color(0xFFF1F5F9), child: image != null ? Image.network(image, fit: BoxFit.cover) : const Icon(Icons.inventory_2))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product['name']?.toString() ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(product['product_type']?.toString().toUpperCase() ?? 'SIMPLE', style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.bold, fontSize: 11)),
          ])),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _ToolCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 20, color: AppTheme.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _Input extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _Input(this.label, this.controller);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final int productId;
  final VoidCallback onRefresh;
  const _ActionsCard({required this.productId, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Full Details'),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductFormPage(productId: productId)));
              onRefresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Manage Variations'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductVariationsPage(productId: productId))),
          ),
        ],
      ),
    );
  }
}