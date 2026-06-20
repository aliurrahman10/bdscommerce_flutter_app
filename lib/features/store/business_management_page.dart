import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/app_theme_controller.dart';
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
    final theme = context.watch<AppThemeController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Business Operations', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.businessSummary(workspace.activeStoreToken!),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          
          bool locked(String key) => features.containsKey(key) && features[key] == false;
          final purchasesLocked = locked('purchase_orders') || locked('inventory');
          final expensesLocked = locked('expenses');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Hero Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: theme.selectedPreset.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: theme.selectedPreset.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inventory & Finance', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatItem('Suppliers', summary['suppliers']?.toString() ?? '0'),
                        _StatItem('Purchases', summary['purchase_orders']?.toString() ?? '0'),
                        _StatItem('Expenses', '৳${summary['monthly_expenses'] ?? 0}'),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text('MANAGEMENT MODULES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.muted, letterSpacing: 1.2)),
              ),

              _ActionTile(
                icon: Icons.storefront_outlined,
                title: 'Suppliers',
                subtitle: 'Manage supplier profiles and contact info',
                page: const SuppliersPage(),
                locked: purchasesLocked,
                requiredPackage: 'Scale',
              ),
              _ActionTile(
                icon: Icons.inventory_outlined,
                title: 'Purchases',
                subtitle: 'Create and track supplier purchase orders',
                page: const PurchasesPage(),
                locked: purchasesLocked,
                requiredPackage: 'Scale',
              ),
              _ActionTile(
                icon: Icons.category_outlined,
                title: 'Expense Categories',
                subtitle: 'Organize your costs with custom categories',
                page: const ExpenseCategoriesPage(),
                locked: expensesLocked,
                requiredPackage: 'Scale',
              ),
              _ActionTile(
                icon: Icons.receipt_long_outlined,
                title: 'Expenses',
                subtitle: 'Track and manage operational daily costs',
                page: const ExpensesPage(),
                locked: expensesLocked,
                requiredPackage: 'Scale',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
    this.locked = false,
    this.requiredPackage = 'Scale',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  final bool locked;
  final String requiredPackage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: LockedFeatureTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        locked: locked,
        requiredPackage: requiredPackage,
        onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}