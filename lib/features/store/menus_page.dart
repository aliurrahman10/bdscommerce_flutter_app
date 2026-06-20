import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class MenusPage extends StatefulWidget {
  const MenusPage({super.key});

  @override
  State<MenusPage> createState() => _MenusPageState();
}

class _MenusPageState extends State<MenusPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.contentMenus(workspace.activeStoreToken!);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _menuDialog([Map<String, dynamic>? menu]) async {
    final name = TextEditingController(text: menu?['name']?.toString() ?? '');
    final slug = TextEditingController(text: menu?['slug']?.toString() ?? '');
    final desc = TextEditingController(text: menu?['description']?.toString() ?? '');
    bool active = menu?['is_active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(menu == null ? 'Add Menu' : 'Edit Menu'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
            const SizedBox(height: 8),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
            CheckboxListTile(value: active, onChanged: (v) => setLocal(() => active = v ?? true), title: const Text('Active'), contentPadding: EdgeInsets.zero),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final api = context.read<WorkspaceController>().storeApi;
      final token = context.read<WorkspaceController>().activeStoreToken!;
      final data = {'name': name.text.trim(), 'slug': slug.text.trim(), 'description': desc.text.trim(), 'is_active': active};
      if (menu == null) {
        await api.createContentMenu(token, data);
      } else {
        await api.updateContentMenu(token, int.parse(menu['id'].toString()), data);
      }
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _itemDialog(Map<String, dynamic> menu, [Map<String, dynamic>? item]) async {
    final label = TextEditingController(text: item?['label']?.toString() ?? '');
    final url = TextEditingController(text: item?['url']?.toString() ?? '');
    final sort = TextEditingController(text: item?['sort_order']?.toString() ?? '0');
    String target = item?['target']?.toString() == '_blank' ? '_blank' : '_self';
    bool active = item?['is_active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Label')),
            const SizedBox(height: 8),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'URL, e.g. /shop or https://...')),
            const SizedBox(height: 8),
            TextField(controller: sort, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: target,
              decoration: const InputDecoration(labelText: 'Target'),
              items: const [DropdownMenuItem(value: '_self', child: Text('Same tab')), DropdownMenuItem(value: '_blank', child: Text('New tab'))],
              onChanged: (v) => setLocal(() => target = v ?? '_self'),
            ),
            CheckboxListTile(value: active, onChanged: (v) => setLocal(() => active = v ?? true), title: const Text('Active'), contentPadding: EdgeInsets.zero),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final api = context.read<WorkspaceController>().storeApi;
      final token = context.read<WorkspaceController>().activeStoreToken!;
      final menuId = int.parse(menu['id'].toString());
      final data = {'label': label.text.trim(), 'url': url.text.trim(), 'sort_order': int.tryParse(sort.text.trim()) ?? 0, 'target': target, 'is_active': active, 'type': 'custom'};
      if (item == null) {
        await api.createContentMenuItem(token, menuId, data);
      } else {
        await api.updateContentMenuItem(token, menuId, int.parse(item['id'].toString()), data);
      }
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteMenu(Map<String, dynamic> menu) async {
    try {
      await context.read<WorkspaceController>().storeApi.deleteContentMenu(context.read<WorkspaceController>().activeStoreToken!, int.parse(menu['id'].toString()));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> menu, Map<String, dynamic> item) async {
    try {
      await context.read<WorkspaceController>().storeApi.deleteContentMenuItem(context.read<WorkspaceController>().activeStoreToken!, int.parse(menu['id'].toString()), int.parse(item['id'].toString()));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menus'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _menuDialog(), icon: const Icon(Icons.add), label: const Text('Menu')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final menus = ((snapshot.data?['data'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
          if (menus.isEmpty) return const Center(child: Text('No menu found.'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: menus.length,
            itemBuilder: (context, index) {
              final menu = menus[index];
              final items = ((menu['items'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.menu_open_outlined, color: AppTheme.primary),
                  title: Text(menu['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${menu['slug'] ?? ''} • ${items.length} links'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'add_item') _itemDialog(menu);
                      if (v == 'edit') _menuDialog(menu);
                      if (v == 'delete') _deleteMenu(menu);
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'add_item', child: Text('Add link')), PopupMenuItem(value: 'edit', child: Text('Edit menu')), PopupMenuItem(value: 'delete', child: Text('Delete menu'))],
                  ),
                  children: [
                    if (items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No menu links.')),
                    ...items.map((item) => ListTile(
                          title: Text(item['label']?.toString() ?? ''),
                          subtitle: Text('${item['url'] ?? '#'} • ${item['is_active'] == true ? 'Active' : 'Inactive'}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _itemDialog(menu, item);
                              if (v == 'delete') _deleteItem(menu, item);
                            },
                            itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                          ),
                        )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
