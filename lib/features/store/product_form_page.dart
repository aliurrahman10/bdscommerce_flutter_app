import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'product_options_page.dart';
import 'product_variations_page.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.productId});
  final int? productId;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _sku = TextEditingController();
  final _regularPrice = TextEditingController();
  final _salePrice = TextEditingController();
  final _stockQty = TextEditingController(text: '0');
  final _shortDescription = TextEditingController();

  String _productType = 'simple';
  bool _active = true;
  bool _inStock = true;
  bool _featured = false;
  bool _saving = false;
  bool _loaded = false;
  bool _replaceExistingVariations = false;
  int? _savedProductId;
  int? _brandId;
  int? _unitId;
  String? _currentThumb;
  XFile? _thumbnailFile;
  List<XFile> _galleryFiles = [];
  List<Map<String, dynamic>> _existingGallery = [];
  Set<int> _selectedCategories = {};
  Set<int> _selectedAttributeValues = {};
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _savedProductId = widget.productId;
    _future = _loadInitial();
  }

  @override
  void dispose() {
    for (final c in [_name, _slug, _sku, _regularPrice, _salePrice, _stockQty, _shortDescription]) { c.dispose(); }
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadInitial() async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    final options = await workspace.storeApi.productOptions(token);
    Map<String, dynamic> product = {};
    if (widget.productId != null) {
      final productResponse = await workspace.storeApi.showProduct(token, widget.productId!);
      product = productResponse['product'] as Map<String, dynamic>? ?? {};
      _fill(product);
    }
    return {'options': options, 'product': product};
  }

  Future<void> _reloadOptions() async {
    setState(() {
      _loaded = false;
      _future = _loadInitial();
    });
  }

  void _fill(Map<String, dynamic> product) {
    if (_loaded) return;
    _loaded = true;
    _name.text = product['name']?.toString() ?? '';
    _slug.text = product['slug']?.toString() ?? '';
    _sku.text = product['sku']?.toString() ?? '';
    _regularPrice.text = product['regular_price']?.toString() ?? '';
    _salePrice.text = product['sale_price']?.toString() ?? '';
    _stockQty.text = product['stock_qty']?.toString() ?? '0';
    _shortDescription.text = product['short_description']?.toString() ?? '';
    _productType = product['product_type']?.toString() == 'variable' ? 'variable' : 'simple';
    _active = product['status'] == true;
    _inStock = product['in_stock'] == true;
    _featured = product['is_featured'] == true;
    _currentThumb = product['thumbnail_url']?.toString();
    _existingGallery = (product['gallery_media'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    _selectedCategories = (product['categories'] as List<dynamic>? ?? []).map((e) => int.tryParse((e as Map)['id'].toString())).whereType<int>().toSet();
    final brand = product['brand'];
    final unit = product['unit'];
    _brandId = int.tryParse((product['brand_id'] ?? (brand is Map ? brand['id'] : null) ?? '').toString());
    _unitId = int.tryParse((product['unit_id'] ?? (unit is Map ? unit['id'] : null) ?? '').toString());
    _selectedAttributeValues = {};
    for (final rawVariation in (product['variations'] as List<dynamic>? ?? [])) {
      final variation = rawVariation as Map<String, dynamic>;
      for (final rawValue in (variation['attribute_values'] as List<dynamic>? ?? [])) {
        final id = int.tryParse((rawValue as Map)['id'].toString());
        if (id != null) _selectedAttributeValues.add(id);
      }
    }
  }

  Future<void> _pickThumb() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _thumbnailFile = file);
  }

  Future<void> _pickGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) setState(() => _galleryFiles = files);
  }

  Map<String, dynamic> _payload() => {
        'name': _name.text.trim(),
        if (_slug.text.trim().isNotEmpty) 'slug': _slug.text.trim(),
        if (_sku.text.trim().isNotEmpty) 'sku': _sku.text.trim(),
        'product_type': _productType,
        'regular_price': _regularPrice.text.trim(),
        'sale_price': _salePrice.text.trim(),
        'stock_qty': int.tryParse(_stockQty.text.trim()) ?? 0,
        'status': _active,
        'in_stock': _inStock,
        'is_featured': _featured,
        'short_description': _shortDescription.text.trim(),
        'category_ids': _selectedCategories.toList(),
        'brand_id': _brandId,
        'unit_id': _unitId,
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      Map<String, dynamic> response;
      if (_savedProductId == null) {
        response = await workspace.storeApi.createProduct(token, _payload());
        _savedProductId = int.parse((response['product'] as Map)['id'].toString());
      } else {
        response = await workspace.storeApi.updateProduct(token, _savedProductId!, _payload());
      }

      if (_thumbnailFile != null) {
        response = await workspace.storeApi.uploadProductThumbnail(token, _savedProductId!, _thumbnailFile!.path);
      }
      if (_galleryFiles.isNotEmpty) {
        response = await workspace.storeApi.uploadProductGallery(token, _savedProductId!, _galleryFiles.map((e) => e.path).toList());
      }

      if (_productType == 'variable' && _selectedAttributeValues.isNotEmpty) {
        await workspace.storeApi.generateProductVariations(
          token,
          _savedProductId!,
          attributeValueIds: _selectedAttributeValues.toList(),
          price: _regularPrice.text,
          salePrice: _salePrice.text,
          stockQty: int.tryParse(_stockQty.text.trim()) ?? 0,
          replaceExisting: _replaceExistingVariations,
        );
      }

      _thumbnailFile = null;
      _galleryFiles = [];
      _loaded = false;
      _fill(response['product'] as Map<String, dynamic>? ?? {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product saved.')));
      if (_productType == 'variable') {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductVariationsPage(productId: _savedProductId!)));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeGallery(int mediaId) async {
    if (_savedProductId == null) return;
    final workspace = context.read<WorkspaceController>();
    final response = await workspace.storeApi.removeProductGalleryImage(workspace.activeStoreToken!, _savedProductId!, mediaId);
    setState(() {
      _loaded = false;
      _fill(response['product'] as Map<String, dynamic>? ?? {});
    });
  }

  Future<void> _removeThumb() async {
    if (_savedProductId == null) {
      setState(() => _thumbnailFile = null);
      return;
    }
    final workspace = context.read<WorkspaceController>();
    final response = await workspace.storeApi.removeProductThumbnail(workspace.activeStoreToken!, _savedProductId!);
    setState(() {
      _loaded = false;
      _thumbnailFile = null;
      _fill(response['product'] as Map<String, dynamic>? ?? {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_savedProductId == null ? 'Add Product' : 'Edit Product'),
        actions: [
          IconButton(
            tooltip: 'Options',
            icon: const Icon(Icons.tune),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductOptionsPage()));
              await _reloadOptions();
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final options = snapshot.data?['options'] as Map<String, dynamic>? ?? {};
          final categories = (options['categories'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final attributes = (options['attributes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final brands = (options['brands'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final units = (options['units'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Product Type', [
                  SegmentedButton<String>(
                    segments: const [ButtonSegment(value: 'simple', label: Text('Simple')), ButtonSegment(value: 'variable', label: Text('Variable'))],
                    selected: {_productType},
                    onSelectionChanged: (v) => setState(() => _productType = v.first),
                  ),
                  if (_productType == 'variable') const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Select attributes below. Variations will be generated from selected values.', style: TextStyle(color: AppTheme.muted)),
                  ),
                ]),
                if (_productType == 'variable') _variableAttributesSection(attributes),
                _section('Images', [
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 92, height: 92, color: const Color(0xFFEAF0F2),
                        child: _thumbnailFile != null
                            ? Image.file(File(_thumbnailFile!.path), fit: BoxFit.cover)
                            : (_currentThumb == null || _currentThumb!.isEmpty ? const Icon(Icons.image_outlined, color: AppTheme.primary) : Image.network(_currentThumb!, fit: BoxFit.cover)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FilledButton.icon(onPressed: _pickThumb, icon: const Icon(Icons.add_photo_alternate), label: const Text('Pick thumbnail')),
                      if (_currentThumb != null || _thumbnailFile != null) TextButton.icon(onPressed: _removeThumb, icon: const Icon(Icons.delete_outline), label: const Text('Remove thumbnail')),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _pickGallery, icon: const Icon(Icons.collections), label: Text(_galleryFiles.isEmpty ? 'Pick gallery images' : '${_galleryFiles.length} gallery image selected')),
                  if (_existingGallery.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: _existingGallery.map((m) {
                    return Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(m['url'].toString(), width: 74, height: 74, fit: BoxFit.cover)),
                      Positioned(right: 0, top: 0, child: InkWell(onTap: () => _removeGallery(int.parse(m['id'].toString())), child: const CircleAvatar(radius: 12, child: Icon(Icons.close, size: 14)))),
                    ]);
                  }).toList()),
                ]),
                _section('Basic Information', [
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Product name *'), validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _regularPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Regular price *'), validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'Valid price required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _salePrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sale price')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _stockQty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _productType == 'variable' ? 'Default variation stock' : 'Stock quantity')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _shortDescription, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Short description')),
                ]),
                _section('Brand & Unit', [
                  DropdownButtonFormField<int?>(
                    value: _safeDropdownValue(_brandId, brands),
                    decoration: const InputDecoration(labelText: 'Brand'),
                    items: [const DropdownMenuItem<int?>(value: null, child: Text('No brand')), ...brands.map((b) => DropdownMenuItem<int?>(value: int.parse(b['id'].toString()), child: Text(b['name']?.toString() ?? 'Brand')))],
                    onChanged: (v) => setState(() => _brandId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _safeDropdownValue(_unitId, units),
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [const DropdownMenuItem<int?>(value: null, child: Text('No unit')), ...units.map((u) => DropdownMenuItem<int?>(value: int.parse(u['id'].toString()), child: Text(u['name']?.toString() ?? 'Unit')))],
                    onChanged: (v) => setState(() => _unitId = v),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductOptionsPage())); await _reloadOptions(); }, icon: const Icon(Icons.add), label: const Text('Manage brands, units & attributes')),
                ]),
                _section('Categories', [
                  if (categories.isEmpty) const Text('No category found.', style: TextStyle(color: AppTheme.muted)) else Wrap(spacing: 8, runSpacing: 8, children: categories.map((category) {
                    final id = int.parse(category['id'].toString());
                    return FilterChip(label: Text(category['name']?.toString() ?? 'Category'), selected: _selectedCategories.contains(id), onSelected: (v) => setState(() => v ? _selectedCategories.add(id) : _selectedCategories.remove(id)));
                  }).toList()),
                ]),
                Card(child: Column(children: [
                  SwitchListTile(title: const Text('Active product'), value: _active, onChanged: (v) => setState(() => _active = v)),
                  SwitchListTile(title: const Text('In stock'), value: _inStock, onChanged: (v) => setState(() => _inStock = v)),
                  SwitchListTile(title: const Text('Featured'), value: _featured, onChanged: (v) => setState(() => _featured = v)),
                ])),
                if (_savedProductId != null && _productType == 'variable') Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductVariationsPage(productId: _savedProductId!))), icon: const Icon(Icons.tune), label: const Text('Manage variations'))),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(_saving ? 'Saving...' : 'Save product')),
              ],
            ),
          );
        },
      ),
    );
  }

  int? _safeDropdownValue(int? current, List<Map<String, dynamic>> items) {
    if (current == null) return null;
    return items.any((e) => int.tryParse(e['id'].toString()) == current) ? current : null;
  }

  Widget _variableAttributesSection(List<Map<String, dynamic>> attributes) {
    return _section('Variation Attributes', [
      if (attributes.isEmpty) ...[
        const Text('No attribute found. Create Size, Color or other attributes first.', style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductOptionsPage())); await _reloadOptions(); }, icon: const Icon(Icons.add), label: const Text('Create Attribute')),
      ] else ...[
        for (final attr in attributes) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(attr['name']?.toString() ?? 'Attribute', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final rawValue in (attr['values'] as List<dynamic>? ?? []))
                _attributeChip(rawValue as Map<String, dynamic>),
            ]),
          ]),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Replace existing variations'),
          subtitle: const Text('Turn on only if you want to rebuild variations from selected values.'),
          value: _replaceExistingVariations,
          onChanged: (v) => setState(() => _replaceExistingVariations = v),
        ),
      ],
    ]);
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

  Widget _section(String title, List<Widget> children) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 14), ...children])));
  }
}
