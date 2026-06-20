import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'category_form_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.managedCategories(workspace.activeStoreToken!, search: _search.text);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _delete(Map<String, dynamic> category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Delete ${category['name']}? Products will be disconnected from this category.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.deleteCategory(workspace.activeStoreToken!, int.parse(category['id'].toString()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> category) async {
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updateCategory(
        workspace.activeStoreToken!,
        int.parse(category['id'].toString()),
        {'status': !(category['status'] == true)},
      );
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openForm({Map<String, dynamic>? category, List<Map<String, dynamic>> categories = const []}) async {
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryFormPage(category: category, categories: categories)));
    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () async {
          final data = await _future;
          final categories = (data['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          await _openForm(categories: categories);
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search category'),
              onSubmitted: (_) => _refresh(),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                if (items.isEmpty) return const Center(child: Text('No categories found.'));
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final category = items[i];
                      final image = category['image_url']?.toString();
                      final active = category['status'] == true;
                      return Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 54,
                              height: 54,
                              color: const Color(0xFFEAF0F2),
                              child: image == null || image.isEmpty
                                  ? const Icon(Icons.category_outlined, color: AppTheme.primary)
                                  : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined)),
                            ),
                          ),
                          title: Text(category['name']?.toString() ?? 'Category', style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('Products: ${category['products_count'] ?? 0} • ${active ? 'Active' : 'Inactive'}${category['show_in_home'] == true ? ' • Home' : ''}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _openForm(category: category, categories: items);
                              if (v == 'toggle') _toggleStatus(category);
                              if (v == 'delete') _delete(category);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'toggle', child: Text(active ? 'Make inactive' : 'Make active')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                          onTap: () => _openForm(category: category, categories: items),
                        ),
                      );
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
