import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'expense_categories_page.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    final expenses = await workspace.storeApi.expenses(token);
    final categories = await workspace.storeApi.expenseCategories(token);
    return {'expenses': expenses, 'categories': categories};
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _openCategoriesPage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpenseCategoriesPage()));
    _refresh();
  }

  Future<void> _categoryDialog([Map<String, dynamic>? category]) async {
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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category name')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                SwitchListTile(value: active, onChanged: (v) => setLocal(() => active = v), title: const Text('Active')),
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
    if (nameCtrl.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category name is required.')));
      return;
    }

    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final data = {'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim(), 'is_active': active};
      if (category == null) {
        await workspace.storeApi.createExpenseCategory(token, data);
      } else {
        await workspace.storeApi.updateExpenseCategory(token, int.parse(category['id'].toString()), data);
      }
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense category saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _expenseDialog(List<Map<String, dynamic>> categories, [Map<String, dynamic>? expense]) async {
    if (categories.isEmpty) {
      final goCategory = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Category required'),
          content: const Text('Expense add korar age at least one expense category create korte hobe.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Category')),
          ],
        ),
      );
      if (goCategory == true) await _categoryDialog();
      return;
    }

    int categoryId = int.tryParse(expense?['category_id']?.toString() ?? '') ?? int.parse(categories.first['id'].toString());
    String status = expense?['status']?.toString() ?? 'approved';
    final amountCtrl = TextEditingController(text: expense?['amount']?.toString() ?? '');
    final dateCtrl = TextEditingController(text: expense?['expense_date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10));
    final methodCtrl = TextEditingController(text: expense?['payment_method']?.toString() ?? 'cash');
    final refCtrl = TextEditingController(text: expense?['reference']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: expense?['notes']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(expense == null ? 'Add Expense' : 'Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((c) => DropdownMenuItem<int>(value: int.parse(c['id'].toString()), child: Text(c['name'].toString()))).toList(),
                  onChanged: (v) => setLocal(() => categoryId = v ?? categoryId),
                ),
                const SizedBox(height: 8),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
                const SizedBox(height: 8),
                TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date YYYY-MM-DD')),
                const SizedBox(height: 8),
                TextField(controller: methodCtrl, decoration: const InputDecoration(labelText: 'Payment method')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const ['pending', 'approved', 'rejected'].map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
                const SizedBox(height: 8),
                TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
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
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final data = {
        'expense_category_id': categoryId,
        'amount': amountCtrl.text.trim(),
        'expense_date': dateCtrl.text.trim(),
        'payment_method': methodCtrl.text.trim(),
        'reference': refCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
        'status': status,
      };
      if (expense == null) {
        await workspace.storeApi.createExpense(token, data);
      } else {
        await workspace.storeApi.updateExpense(token, int.parse(expense['id'].toString()), data);
      }
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _openCategoriesPage, icon: const Icon(Icons.category_outlined), tooltip: 'Expense Categories'),
        ],
      ),
      floatingActionButton: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final categoriesMap = snapshot.data?['categories'] as Map<String, dynamic>? ?? {};
          final categories = (categoriesMap['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return FloatingActionButton.extended(
            onPressed: () => _expenseDialog(categories),
            icon: const Icon(Icons.add),
            label: const Text('Expense'),
          );
        },
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));

          final expensesMap = snapshot.data?['expenses'] as Map<String, dynamic>? ?? {};
          final categoriesMap = snapshot.data?['categories'] as Map<String, dynamic>? ?? {};
          final expenses = (expensesMap['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final categories = (categoriesMap['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(Icons.account_tree_outlined, color: AppTheme.primary),
                  title: const Text('Dependency: Expense Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(categories.isEmpty ? 'Expense add korar age category create korte hobe.' : '${categories.length} category available'),
                  trailing: FilledButton.tonal(onPressed: _openCategoriesPage, child: const Text('Manage')),
                ),
              ),
              const SizedBox(height: 10),
              if (categories.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No expense category found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 6),
                        const Text('Example category: Office Rent, Packaging, Delivery Cost, Staff Salary.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: () => _categoryDialog(), icon: const Icon(Icons.add), label: const Text('Add Expense Category')),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 6),
              if (expenses.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No expense found.'))),
              ...expenses.map((expense) => Card(
                    child: ListTile(
                      title: Text('৳ ${expense['amount']} • ${expense['category_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${expense['expense_date']} • ${expense['payment_method']} • ${expense['status']}'),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _expenseDialog(categories, expense),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
