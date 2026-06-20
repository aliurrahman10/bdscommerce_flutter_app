import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'variation_form_page.dart';

class ProductVariationsPage extends StatefulWidget {
  const ProductVariationsPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductVariationsPage> createState() => _ProductVariationsPageState();
}

class _ProductVariationsPageState extends State<ProductVariationsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.productVariations(workspace.activeStoreToken!, widget.productId);
  }

  void _refresh() => setState(() { _future = _load(); });

  Future<void> _delete(int variationId) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete variation?'), content: const Text('This variation will be removed.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    final workspace = context.read<WorkspaceController>();
    await workspace.storeApi.deleteVariation(workspace.activeStoreToken!, widget.productId, variationId);
    _refresh();
  }

  String _variationSubtitle(Map<String, dynamic> variation) {
    final attrs = (variation['attribute_values'] as List<dynamic>? ?? [])
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final attr = item['attribute'] as Map<String, dynamic>?;
          final attrName = attr?['name']?.toString();
          final value = item['value']?.toString() ?? '';
          return attrName == null || attrName.isEmpty ? value : '$attrName: $value';
        })
        .where((e) => e.isNotEmpty)
        .join(' • ');
    final base = 'SKU: ${variation['sku'] ?? '-'} • Stock: ${variation['stock_qty'] ?? 0}';
    return attrs.isEmpty ? base : '$attrs\n$base';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Variations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VariationFormPage(productId: widget.productId)));
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = (snapshot.data?['data'] as List<dynamic>? ?? []);
          if (items.isEmpty) return const Center(child: Text('No variation found. Add Size/Color/Variant.'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final variation = items[i] as Map<String, dynamic>;
              final image = variation['image_url']?.toString();
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(width: 54, height: 54, color: const Color(0xFFEAF0F2), child: image == null || image.isEmpty ? const Icon(Icons.tune, color: AppTheme.primary) : Image.network(image, fit: BoxFit.cover)),
                  ),
                  title: Text(variation['variation_name']?.toString() ?? 'Variation', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_variationSubtitle(variation)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VariationFormPage(productId: widget.productId, variation: variation)));
                        _refresh();
                      } else if (value == 'delete') {
                        _delete(int.parse(variation['id'].toString()));
                      }
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VariationFormPage(productId: widget.productId, variation: variation)));
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
