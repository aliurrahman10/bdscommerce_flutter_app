import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class CategoryFormPage extends StatefulWidget {
  const CategoryFormPage({super.key, this.category, this.categories = const []});
  final Map<String, dynamic>? category;
  final List<Map<String, dynamic>> categories;

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _sortOrder = TextEditingController();

  bool _active = true;
  bool _showInHome = false;
  bool _saving = false;
  int? _parentId;
  String? _imageUrl;
  XFile? _imageFile;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _name.text = c['name']?.toString() ?? '';
      _slug.text = c['slug']?.toString() ?? '';
      _description.text = c['description']?.toString() ?? '';
      _sortOrder.text = c['sort_order']?.toString() ?? '';
      _active = c['status'] == true;
      _showInHome = c['show_in_home'] == true;
      _parentId = int.tryParse((c['parent_id'] ?? '').toString());
      _imageUrl = c['image_url']?.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _imageFile = file);
  }

  Map<String, dynamic> _payload() => {
        'name': _name.text.trim(),
        if (_slug.text.trim().isNotEmpty) 'slug': _slug.text.trim(),
        'description': _description.text.trim(),
        'parent_id': _parentId,
        'status': _active,
        'show_in_home': _showInHome,
        if (_sortOrder.text.trim().isNotEmpty) 'sort_order': int.tryParse(_sortOrder.text.trim()) ?? 0,
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      Map<String, dynamic> response;
      int categoryId;

      if (_isEdit) {
        categoryId = int.parse(widget.category!['id'].toString());
        response = await workspace.storeApi.updateCategory(token, categoryId, _payload());
      } else {
        response = await workspace.storeApi.createCategory(token, _payload());
        categoryId = int.parse((response['category'] as Map)['id'].toString());
      }

      if (_imageFile != null) {
        response = await workspace.storeApi.uploadCategoryImage(token, categoryId, _imageFile!.path);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category saved.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeImage() async {
    if (!_isEdit) {
      setState(() => _imageFile = null);
      return;
    }
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.removeCategoryImage(workspace.activeStoreToken!, int.parse(widget.category!['id'].toString()));
      setState(() {
        _imageUrl = null;
        _imageFile = null;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions = widget.categories.where((c) => c['id'].toString() != (widget.category?['id']?.toString() ?? '')).toList();
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Category' : 'Add Category')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Category'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Category Image', [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 92,
                    height: 92,
                    color: const Color(0xFFEAF0F2),
                    child: _imageFile != null
                        ? Image.file(File(_imageFile!.path), fit: BoxFit.cover)
                        : (_imageUrl == null || _imageUrl!.isEmpty
                            ? const Icon(Icons.category_outlined, color: AppTheme.primary, size: 34)
                            : Image.network(_imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_outlined), label: const Text('Choose Image')),
                    if (_imageFile != null || (_imageUrl != null && _imageUrl!.isNotEmpty))
                      TextButton.icon(onPressed: _removeImage, icon: const Icon(Icons.delete_outline), label: const Text('Remove Image')),
                  ]),
                ),
              ]),
            ]),
            _section('Details', [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Category name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug', hintText: 'auto generated if empty')),
              const SizedBox(height: 12),
              TextFormField(controller: _description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _parentId,
                decoration: const InputDecoration(labelText: 'Parent category'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('No parent')),
                  for (final c in parentOptions) DropdownMenuItem<int?>(value: int.tryParse(c['id'].toString()), child: Text(c['name']?.toString() ?? 'Category')),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _sortOrder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort order')),
              const SizedBox(height: 12),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Show in home'), value: _showInHome, onChanged: (v) => setState(() => _showInHome = v)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }
}
