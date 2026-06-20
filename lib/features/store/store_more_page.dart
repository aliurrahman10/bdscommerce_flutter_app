import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/locked_feature.dart';
import '../account/my_account_page.dart';
import 'access_management_page.dart';
import 'appearance_management_page.dart';
import 'business_management_page.dart';
import 'content_management_page.dart';
import 'categories_page.dart';
import 'customers_page.dart';
import 'mobile_quality_page.dart';
import 'operations_page.dart';
import 'reports_page.dart';
import 'inventory_management_page.dart';
import 'notification_center_page.dart';
import 'trash_center_page.dart';
import 'store_settings_page.dart';

class StoreMorePage extends StatelessWidget {
  const StoreMorePage({super.key});

  Future<Map<String, bool>> _features(BuildContext context) async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken;
    if (token == null || token.isEmpty) return <String, bool>{};
    try {
      final dashboard = await workspace.storeApi.dashboard(token);
      return checkedFeaturesFromAudit(dashboard['feature_audit'] as Map<String, dynamic>?);
    } catch (_) {
      return <String, bool>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: FutureBuilder<Map<String, bool>>(
        future: _features(context),
        builder: (context, snapshot) {
          final features = snapshot.data ?? <String, bool>{};
          bool isLocked(String key) => features.containsKey(key) && features[key] != true;
          bool anyLocked(List<String> keys) => keys.any(isLocked);
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _MoreTile(icon: Icons.notifications_active_outlined, title: 'Notification Center', subtitle: 'Pending orders, push logs, audit logs and plan alerts', page: const NotificationCenterPage(), locked: isLocked('audit_logs'), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.delete_outline, title: 'Trash Center', subtitle: 'Restore or permanently delete orders and products', page: const TrashCenterPage(), locked: anyLocked(['orders', 'products']), requiredPackage: 'Launch'),
              _MoreTile(icon: Icons.web_outlined, title: 'Content & SEO', subtitle: 'Pages, blog, menus and SEO fields', page: const ContentManagementPage(), locked: anyLocked(['page_builder', 'menu_builder']), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.person_outline, title: 'My Account', subtitle: 'Profile, password and device sessions', page: const MyAccountPage()),
              _MoreTile(icon: Icons.admin_panel_settings_outlined, title: 'Access Management', subtitle: 'Staff accounts, roles and permissions', page: const AccessManagementPage(), locked: isLocked('staff_accounts'), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.palette_outlined, title: 'Appearance', subtitle: 'Theme basic settings and website sliders', page: const AppearanceManagementPage(), locked: isLocked('theme_customization'), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.inventory_2_outlined, title: 'Inventory & Returns', subtitle: 'Stock adjustment, warehouses and returns', page: const InventoryManagementPage(), locked: anyLocked(['inventory', 'returns']), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.tune_outlined, title: 'Operations', subtitle: 'Coupons, delivery, payments and couriers', page: const OperationsPage(), locked: anyLocked(['coupons', 'payment_gateways', 'courier_integrations']), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.verified_user_outlined, title: 'Push & Plan Audit', subtitle: 'Firebase status, test push and subscription feature sync', page: const MobileQualityPage()),
              _MoreTile(icon: Icons.business_center_outlined, title: 'Business Operations', subtitle: 'Suppliers, purchase orders and expenses', page: const BusinessManagementPage(), locked: anyLocked(['purchase_orders', 'expenses']), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.category_outlined, title: 'Categories', subtitle: 'Manage category image, status and home visibility', page: const CategoriesPage(), locked: isLocked('categories'), requiredPackage: 'Launch'),
              _MoreTile(icon: Icons.people_alt_outlined, title: 'Customers', subtitle: 'View customer details and order history', page: const CustomersPage()),
              _MoreTile(icon: Icons.insights_outlined, title: 'Reports', subtitle: 'Sales, low stock and latest orders', page: const ReportsPage(), locked: isLocked('advanced_reports'), requiredPackage: 'Scale'),
              _MoreTile(icon: Icons.settings_outlined, title: 'Store Settings', subtitle: 'Store identity and mobile-safe store information', page: const StoreSettingsPage()),
            ],
          );
        },
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.page, this.locked = false, this.requiredPackage = 'a higher plan'});
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