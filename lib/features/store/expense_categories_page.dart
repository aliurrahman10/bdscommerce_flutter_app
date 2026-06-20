import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class ExpenseCategoriesPage extends StatefulWidget {
  const ExpenseCategoriesPage({super.key});

  @override
  State<ExpenseCategoriesPage> createState() => _ExpenseCategoriesPageState();
}

class _ExpenseCategoriesPageState extends State<ExpenseCategoriesPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.expenseCategories(workspace.activeStoreToken!);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? category]) async {
    final nameCtrl = TextEditingController(text: category?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: category?['description']?.toString() ?? '');
    bool active = category?['is_active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(category == null ? 'Add Expense Category' : 'Edit Expense Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Category name'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setLocal(() => active = value),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category name is required.')));
      return;
    }

    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final data = {'name': name, 'description': descCtrl.text.trim(), 'is_active': active};
      if (category == null) {
        await workspace.storeApi.createExpenseCategory(token, data);
      } else {
        await workspace.storeApi.updateExpenseCategory(token, int.parse(category['id'].toString()), data);
      }
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense category saved.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _delete(Map<String, dynamic> category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Delete ${category['name']}? Existing expenses may block deletion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.deleteExpenseCategory(workspace.activeStoreToken!, int.parse(category['id'].toString()));
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense category deleted.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Expense Categories', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));

          final categories = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 64, color: AppTheme.primary.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text('No categories found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text('Create categories to organize your expenses effectively (e.g., Rent, Salaries, Utilities).', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 24),
                    FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Add Category')),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final active = category['is_active'] != false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: active ? AppTheme.primary.withOpacity(.12) : Colors.grey.withOpacity(.15),
                      foregroundColor: active ? AppTheme.primary : Colors.grey,
                      child: Icon(active ? Icons.check_circle_outline : Icons.pause_circle_outline),
                    ),
                    title: Text(category['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(category['description']?.toString() ?? ''),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _openForm(category);
                        if (value == 'delete') _delete(category);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => _openForm(category),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}