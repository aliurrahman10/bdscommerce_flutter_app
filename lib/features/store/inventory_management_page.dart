import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'returns_page.dart';
import 'stock_page.dart';
import 'warehouses_page.dart';
import '../../shared/widgets/locked_feature.dart';

class InventoryManagementPage extends StatelessWidget {
  const InventoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory & Returns')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.inventorySummary(workspace.activeStoreToken!),
        builder: (context, snapshot) {
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          final inventoryLocked = features['inventory'] == false;
          final returnsLocked = features['returns'] == false;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Inventory Control', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Warehouses: ${summary['warehouses'] ?? 0} • Stock Items: ${summary['stock_items'] ?? 0} • Low Stock: ${summary['low_stock'] ?? 0}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 14),
            _Tile(icon: Icons.warehouse_outlined, title: 'Warehouses', subtitle: 'Create, edit and set default warehouse', page: const WarehousesPage(), locked: inventoryLocked),
            _Tile(icon: Icons.inventory_2_outlined, title: 'Stock Adjustment', subtitle: 'View stock, adjust quantity and see movement history', page: const StockPage(), locked: inventoryLocked),
            _Tile(icon: Icons.assignment_return_outlined, title: 'Returns / Refunds', subtitle: 'Create return request and receive returned items', page: const ReturnsPage(), locked: returnsLocked),
          ]);
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  // ignore: unused_element_parameter
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
