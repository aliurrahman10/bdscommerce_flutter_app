import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class VariationFormPage extends StatefulWidget {
  const VariationFormPage({super.key, required this.productId, this.variation});
  final int productId;
  final Map<String, dynamic>? variation;

  @override
  State<VariationFormPage> createState() => _VariationFormPageState();
}

class _VariationFormPageState extends State<VariationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _stock = TextEditingController(text: '0');
  XFile? _image;
  String? _currentImage;
  bool _saving = false;
  bool _loaded = false;
  Set<int> _selectedAttributeValues = {};
  late Future<Map<String, dynamic>> _future;

  bool get isEdit => widget.variation != null;
  int? get variationId => widget.variation == null ? null : int.parse(widget.variation!['id'].toString());

  @override
  void initState() {
    super.initState();
    _future = _loadOptions();
    final v = widget.variation;
    if (v != null) {
      _name.text = v['variation_name']?.toString() ?? '';
      _sku.text = v['sku']?.toString() ?? '';
      _price.text = v['price']?.toString() ?? '';
      _salePrice.text = v['sale_price']?.toString() ?? '';
      _stock.text = v['stock_qty']?.toString() ?? '0';
      _currentImage = v['image_url']?.toString();
      _selectedAttributeValues = (v['attribute_values'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse((e as Map)['id'].toString()))
          .whereType<int>()
          .toSet();
    }
  }

  Future<Map<String, dynamic>> _loadOptions() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.productOptions(workspace.activeStoreToken!);
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _price, _salePrice, _stock]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _image = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final payload = {
        'variation_name': _name.text.trim(),
        'sku': _sku.text.trim(),
        'price': _price.text.trim(),
        'sale_price': _salePrice.text.trim(),
        'stock_qty': int.tryParse(_stock.text.trim()) ?? 0,
        'attribute_value_ids': _selectedAttributeValues.toList(),
      };
      Map<String, dynamic> response;
      int id;
      if (variationId == null) {
        response = await workspace.storeApi.createVariation(token, widget.productId, payload);
        id = int.parse((response['variation'] as Map)['id'].toString());
      } else {
        id = variationId!;
        response = await workspace.storeApi.updateVariation(token, widget.productId, id, payload);
      }
      if (_image != null) {
        response = await workspace.storeApi.uploadVariationImage(token, widget.productId, id, _image!.path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Variation saved.')));
      Navigator.pop(context, response['variation']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeImage() async {
    if (variationId == null) return;
    final workspace = context.read<WorkspaceController>();
    final response = await workspace.storeApi.removeVariationImage(workspace.activeStoreToken!, widget.productId, variationId!);
    final variation = response['variation'] as Map<String, dynamic>? ?? {};
    setState(() {
      _image = null;
      _currentImage = variation['image_url']?.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Variation' : 'Add Variation')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final attributes = (snapshot.data?['attributes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          if (!_loaded) {
            _loaded = true;
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Variation Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(16), child: Container(width: 88, height: 88, color: const Color(0xFFEAF0F2), child: _image != null ? Image.file(File(_image!.path), fit: BoxFit.cover) : (_currentImage == null || _currentImage!.isEmpty ? const Icon(Icons.image, color: AppTheme.primary) : Image.network(_currentImage!, fit: BoxFit.cover)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FilledButton.icon(onPressed: _pickImage, icon: const Icon(Icons.add_photo_alternate), label: const Text('Pick image')),
                      if (_currentImage != null || _image != null) TextButton.icon(onPressed: _removeImage, icon: const Icon(Icons.delete_outline), label: const Text('Remove image')),
                    ])),
                  ]),
                ]))),
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Attribute Values', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (attributes.isEmpty) const Text('No attribute found. Create attributes first from Product Options.', style: TextStyle(color: AppTheme.muted))
                  else for (final attr in attributes) Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(attr['name']?.toString() ?? 'Attribute', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final rawValue in (attr['values'] as List<dynamic>? ?? [])) _attributeChip(rawValue as Map<String, dynamic>),
                      ]),
                    ]),
                  ),
                ]))),
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Variation name'), validator: (v) => (v == null || v.trim().isEmpty) && _selectedAttributeValues.isEmpty ? 'Name or attribute value required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price *'), validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'Valid price required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _salePrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sale price')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock quantity')),
                ]))),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(_saving ? 'Saving...' : 'Save variation')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _attributeChip(Map<String, dynamic> value) {
    final id = int.parse(value['id'].toString());
    final selected = _selectedAttributeValues.contains(id);
    return FilterChip(
      label: Text(value['value']?.toString() ?? 'Value'),
      selected: selected,
      onSelected: (v) => setState(() => v ? _selectedAttributeValues.add(id) : _selectedAttributeValues.remove(id)),
    );
  }
}
