import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/locked_feature.dart';
import 'expense_categories_page.dart';
import 'expenses_page.dart';
import 'purchases_page.dart';
import 'suppliers_page.dart';

class BusinessManagementPage extends StatelessWidget {
  const BusinessManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Business Operations')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.businessSummary(workspace.activeStoreToken!),
        builder: (context, snapshot) {
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          bool locked(String key) => features.containsKey(key) && features[key] == false;
          final purchasesLocked = locked('purchase_orders') || locked('inventory');
          final expensesLocked = locked('expenses');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inventory & Finance', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      'Suppliers: ${summary['suppliers'] ?? 0} • Purchases: ${summary['purchase_orders'] ?? 0} • Monthly Expense: ৳${summary['monthly_expenses'] ?? 0}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                color: AppTheme.primary.withOpacity(.06),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dependency guide', style: TextStyle(fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('Purchase needs Supplier + Product. Expense needs Expense Category. Locked items show the required plan before upgrade.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _Tile(icon: Icons.storefront_outlined, title: 'Suppliers', subtitle: 'Purchase order create korar dependency', page: const SuppliersPage(), locked: purchasesLocked, requiredPackage: 'Scale'),
              _Tile(icon: Icons.inventory_outlined, title: 'Purchases', subtitle: 'Supplier + Product select kore purchase order create', page: const PurchasesPage(), locked: purchasesLocked, requiredPackage: 'Scale'),
              _Tile(icon: Icons.category_outlined, title: 'Expense Categories', subtitle: 'Expense add korar age category create korte hobe', page: const ExpenseCategoriesPage(), locked: expensesLocked, requiredPackage: 'Scale'),
              _Tile(icon: Icons.receipt_long_outlined, title: 'Expenses', subtitle: 'Category select kore expense records manage', page: const ExpensesPage(), locked: expensesLocked, requiredPackage: 'Scale'),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.page, this.locked = false, this.requiredPackage = 'Scale'});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  final bool locked;
  final String requiredPackage;

  @override
  Widget build(BuildContext context) {
    return LockedFeatureTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      locked: locked,
      requiredPackage: requiredPackage,
      onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
    );
  }
}