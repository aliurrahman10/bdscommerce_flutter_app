import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class ProductOptionsPage extends StatefulWidget {
  const ProductOptionsPage({super.key});

  @override
  State<ProductOptionsPage> createState() => _ProductOptionsPageState();
}

class _ProductOptionsPageState extends State<ProductOptionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.productOptions(workspace.activeStoreToken!);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _createAttribute() async {
    final result = await _attributeDialog();
    if (result == null) return;
    final workspace = context.read<WorkspaceController>();
    await workspace.storeApi.createAttribute(workspace.activeStoreToken!, result);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attribute created.')));
    _refresh();
  }

  Future<void> _editAttribute(Map<String, dynamic> attribute) async {
    final result = await _attributeDialog(attribute: attribute);
    if (result == null) return;
    final workspace = context.read<WorkspaceController>();
    await workspace.storeApi.updateAttribute(workspace.activeStoreToken!, int.parse(attribute['id'].toString()), result);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attribute updated.')));
    _refresh();
  }

  Future<void> _deleteAttribute(Map<String, dynamic> attribute) async {
    final ok = await _confirm('Delete attribute?', 'All values under this attribute will be removed.');
    if (ok != true) return;
    final workspace = context.read<WorkspaceController>();
    await workspace.storeApi.deleteAttribute(workspace.activeStoreToken!, int.parse(attribute['id'].toString()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attribute deleted.')));
    _refresh();
  }

  Future<void> _addAttributeValue(Map<String, dynamic> attribute) async {
    final value = await _textDialog(title: 'Add value', label: 'Value name');
    if (value == null || value.trim().isEmpty) return;
    final workspace = context.read<WorkspaceController>();
    await workspace.storeApi.createAttributeValue(workspace.activeStoreToken!, int.parse(attribute['id'].toString()), value.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Value added.')));
    _refresh();
  }

  Future<void> _editAttributeValue(Map<String, dynamic> attribute, Map<String, dynamic> value) async {
    final text = await _textDialog(title: 'Edit value', label: 'Value name', initial: value['value']?.toString() ?? '');
    if (text == null || text.trim().isEmpty) return;
    final workspace = context.read<WorkspaceController>();
    await workspace.storeApi.updateAttributeValue(
      workspace.activeStoreToken!,
      int.parse(attribute['id'].toString()),
      int.parse(value['id'].toString()),
      text.trim(),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Value updated.')));
    _refresh();
  }

  Future<void> _deleteAttributeValue(Map<String, dynamic> attribute, Map<String, dynamic> value) async {
    final ok = await _confirm('Delete value?', 'This value will be removed from the attribute.');
    if (ok != true) return;
    final workspace = context.read<WorkspaceController>();
    await workspace.storeApi.deleteAttributeValue(
      workspace.activeStoreToken!,
      int.parse(attribute['id'].toString()),
      int.parse(value['id'].toString()),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Value deleted.')));
    _refresh();
  }

  Future<void> _createBrand() async => _saveSimpleOption('brand');
  Future<void> _createUnit() async => _saveSimpleOption('unit');

  Future<void> _saveSimpleOption(String type, {Map<String, dynamic>? item}) async {
    final text = await _textDialog(title: item == null ? 'Add ${_label(type)}' : 'Edit ${_label(type)}', label: '${_label(type)} name', initial: item?['name']?.toString() ?? '');
    if (text == null || text.trim().isEmpty) return;
    final workspace = context.read<WorkspaceController>();
    if (type == 'brand') {
      if (item == null) {
        await workspace.storeApi.createBrand(workspace.activeStoreToken!, {'name': text.trim(), 'status': true});
      } else {
        await workspace.storeApi.updateBrand(workspace.activeStoreToken!, int.parse(item['id'].toString()), {'name': text.trim()});
      }
    } else {
      if (item == null) {
        await workspace.storeApi.createUnit(workspace.activeStoreToken!, {'name': text.trim(), 'status': true});
      } else {
        await workspace.storeApi.updateUnit(workspace.activeStoreToken!, int.parse(item['id'].toString()), {'name': text.trim()});
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_label(type)} saved.')));
    _refresh();
  }

  Future<void> _deleteSimpleOption(String type, Map<String, dynamic> item) async {
    final ok = await _confirm('Delete ${_label(type)}?', 'Products using this ${_label(type).toLowerCase()} will be disconnected from it.');
    if (ok != true) return;
    final workspace = context.read<WorkspaceController>();
    if (type == 'brand') {
      await workspace.storeApi.deleteBrand(workspace.activeStoreToken!, int.parse(item['id'].toString()));
    } else {
      await workspace.storeApi.deleteUnit(workspace.activeStoreToken!, int.parse(item['id'].toString()));
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_label(type)} deleted.')));
    _refresh();
  }

  String _label(String type) => type == 'brand' ? 'Brand' : 'Unit';

  Future<Map<String, dynamic>?> _attributeDialog({Map<String, dynamic>? attribute}) async {
    final name = TextEditingController(text: attribute?['name']?.toString() ?? '');
    final values = TextEditingController();
    bool variation = attribute == null ? true : attribute['is_variation'] == true;
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(attribute == null ? 'Add attribute' : 'Edit attribute'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Attribute name, e.g. Size')),
                  if (attribute == null) ...[
                    const SizedBox(height: 12),
                    TextField(controller: values, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Values, comma separated', hintText: 'S, M, L, XL')),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Use for variation'), value: variation, onChanged: (v) => setDialogState(() => variation = v)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  Navigator.pop(context, {
                    'name': name.text.trim(),
                    'is_variation': variation,
                    if (attribute == null) 'values': values.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      return result;
    } finally {
      // Keep dialog controllers alive until Flutter fully removes dialog dependents.
    }
  }

  Future<String?> _textDialog({required String title, required String label, String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: label)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
          ],
        ),
      );
      return result;
    } finally {
      // Keep dialog controller alive until Flutter fully removes dialog dependents.
    }
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Options'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Attributes'), Tab(text: 'Brands'), Tab(text: 'Units')],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final data = snapshot.data ?? {};
          final attrs = (data['attributes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final brands = (data['brands'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final units = (data['units'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return TabBarView(
            controller: _tabController,
            children: [
              _attributesTab(attrs),
              _simpleTab(type: 'brand', items: brands, onAdd: _createBrand),
              _simpleTab(type: 'unit', items: units, onAdd: _createUnit),
            ],
          );
        },
      ),
    );
  }

  Widget _attributesTab(List<Map<String, dynamic>> attributes) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(onPressed: _createAttribute, icon: const Icon(Icons.add), label: const Text('Add Attribute')),
        const SizedBox(height: 12),
        if (attributes.isEmpty) const _EmptyHint(text: 'No attribute found. Add Size, Color, Material etc.'),
        for (final attribute in attributes) Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(attribute['name']?.toString() ?? 'Attribute', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => _addAttributeValue(attribute), icon: const Icon(Icons.add_circle_outline), tooltip: 'Add value'),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editAttribute(attribute);
                    if (v == 'delete') _deleteAttribute(attribute);
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final raw in (attribute['values'] as List<dynamic>? ?? []))
                  _ValueChip(
                    value: raw as Map<String, dynamic>,
                    onEdit: () => _editAttributeValue(attribute, raw),
                    onDelete: () => _deleteAttributeValue(attribute, raw),
                  ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _simpleTab({required String type, required List<Map<String, dynamic>> items, required VoidCallback onAdd}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text('Add ${_label(type)}')),
        const SizedBox(height: 12),
        if (items.isEmpty) _EmptyHint(text: 'No ${_label(type).toLowerCase()} found.'),
        for (final item in items) Card(
          child: ListTile(
            title: Text(item['name']?.toString() ?? _label(type), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(item['status'] == true ? 'Active' : 'Inactive'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _saveSimpleOption(type, item: item);
                if (v == 'delete') _deleteSimpleOption(type, item);
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
            ),
          ),
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.value, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> value;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value['value']?.toString() ?? 'Value', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 4),
        InkWell(onTap: onEdit, child: const Icon(Icons.edit, size: 16, color: AppTheme.primary)),
        const SizedBox(width: 4),
        InkWell(onTap: onDelete, child: const Icon(Icons.close, size: 16, color: Colors.redAccent)),
      ]),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)))));
  }
}
