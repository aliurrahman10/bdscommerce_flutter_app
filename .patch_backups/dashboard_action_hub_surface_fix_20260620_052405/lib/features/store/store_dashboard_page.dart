import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_copy.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/app_mode.dart';
import '../../core/state/app_theme_controller.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/premium_widgets.dart';
import '../../shared/widgets/renewal_warning_banner.dart';
import '../account/my_account_page.dart';
import '../guide/desktop_feature_guide_page.dart';
import '../portal/portal_renew_page.dart';
import 'access_management_page.dart';
import 'appearance_management_page.dart';
import 'business_management_page.dart';
import 'categories_page.dart';
import 'content_management_page.dart';
import 'customers_page.dart';
import 'inventory_management_page.dart';
import 'mobile_quality_page.dart';
import 'notification_center_page.dart';
import 'operations_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'reports_page.dart';
import 'trash_center_page.dart';
import '../../shared/widgets/locked_feature.dart';

class StoreDashboardPage extends StatefulWidget {
  const StoreDashboardPage({super.key});

  @override
  State<StoreDashboardPage> createState() => _StoreDashboardPageState();
}

class _StoreDashboardPageState extends State<StoreDashboardPage> {
  late Future<_StoreDashboardPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StoreDashboardPayload> _load() async {
    final workspace = context.read<WorkspaceController>();
    final dashboard = await workspace.storeApi.dashboard(workspace.activeStoreToken!);
    final meta = await AppMeta.load(workspace);
    return _StoreDashboardPayload(dashboard: dashboard, meta: meta);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final theme = context.watch<AppThemeController>();
    final lang = theme.language;
    final t = theme.t;
    return FutureBuilder<_StoreDashboardPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        final payload = snapshot.data!;
        final dashboard = payload.dashboard;
        final copy = payload.meta.copy;
        final summary = dashboard['summary'] as Map<String, dynamic>? ?? {};
        final features = checkedFeaturesFromAudit(dashboard['feature_audit'] as Map<String, dynamic>?);
        bool isLocked(String key) => features.containsKey(key) && features[key] != true;
        final renewalPayload = <String, dynamic>{
          'dashboard': dashboard,
          'tenant': workspace.activeTenant ?? const <String, dynamic>{},
          // Phase 12H.5: store renewal date arrives from ecommerce support/meta in Store mode.
          // AppMeta now uses the active mode first, so this payload contains ecommerce tenant expires_at.
          'support': payload.meta.support,
          'renewal': payload.meta.support['renewal'] ?? const <String, dynamic>{},
          'store_tenant': payload.meta.support['tenant'] ?? const <String, dynamic>{},
        };

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: [
              RenewalWarningBanner(
                payload: renewalPayload,
                copy: copy,
                onRenewNow: () async {
                  if (workspace.hasPortalSession) {
                    await workspace.switchMode(AppMode.portal);
                    if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PortalRenewPage()));
                  } else if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesktopFeatureGuidePage()));
                  }
                },
              ),
              PremiumHeroCard(
                title: copy.localized(lang, 'store_dashboard_title', en: workspace.activeStoreSlug ?? 'Store Admin', bn: workspace.activeStoreSlug ?? 'Store Admin'),
                subtitle: copy.localized(lang, 'store_dashboard_subtitle', en: 'Premium mobile control room for orders, products, stock, payments and daily store operations.', bn: 'অর্ডার, প্রোডাক্ট, স্টক, পেমেন্ট ও দৈনিক Store অপারেশনের জন্য প্রিমিয়াম Mobile control room।'),
                icon: Icons.storefront_rounded,
                badge: copy.localized(lang, 'store_dashboard_badge', en: 'Store Admin', bn: 'Store Admin'),
                action: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.30))),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesktopFeatureGuidePage())),
                  icon: const Icon(Icons.desktop_windows_rounded),
                  label: Text(copy.localized(lang, 'store_dashboard_guide_button', en: 'Desktop Feature Guide', bn: 'Desktop Feature Guide')),
                ),
              ),
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final totalOrders = _asInt(summary['total_orders']);
                final todayOrders = _asInt(summary['today_orders']);
                final pendingOrders = _asInt(summary['pending_orders']);
                final paidOrders = _asInt(summary['paid_orders']);
                final unpaidOrders = totalOrders > paidOrders ? totalOrders - paidOrders : 0;
                final todaySales = summary['today_sales']?.toString() ?? '0';

                return Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.18,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _DashboardMetricCard(title: t('Orders', 'অর্ডার'), value: totalOrders, icon: Icons.shopping_bag_rounded, gradient: AppTheme.premiumGradient, caption: t('Open all orders', 'সব অর্ডার দেখুন'), onTap: () => _openPage(const OrdersPage())),
                        _DashboardMetricCard(title: t('Today', 'আজ'), value: todayOrders, icon: Icons.today_rounded, gradient: AppTheme.infoGradient, caption: t('Open sales report', 'Sales report খুলুন'), onTap: () => _openPage(const ReportsPage())),
                        _DashboardMetricCard(title: t('Pending', 'পেন্ডিং'), value: pendingOrders, icon: Icons.pending_actions_rounded, gradient: AppTheme.warningGradient, caption: t('Tap to handle', 'Tap করে কাজ করুন'), onTap: () => _openPage(const OrdersPage(initialStatus: 'pending'))),
                        _DashboardMetricCard(title: t('Unpaid', 'আনপেইড'), value: unpaidOrders, icon: Icons.payments_rounded, gradient: AppTheme.dangerGradient, caption: t('Collect payment', 'Payment collect করুন'), onTap: () => _openPage(const OrdersPage(initialPaymentStatus: 'unpaid'))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _NeedsAttentionPanel(
                      pendingOrders: pendingOrders,
                      unpaidOrders: unpaidOrders,
                      todaySales: todaySales,
                      onPending: () => _openPage(const OrdersPage(initialStatus: 'pending')),
                      onUnpaid: () => _openPage(const OrdersPage(initialPaymentStatus: 'unpaid')),
                      onNotifications: () => _openPage(const NotificationCenterPage()),
                      onReports: () => _openPage(const ReportsPage()),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 18),
              PremiumSectionTitle(
                title: copy.localized(lang, 'store_actions_title', en: 'Quick actions', bn: 'দ্রুত অ্যাকশন'),
                subtitle: copy.localized(lang, 'store_actions_subtitle', en: 'Color-coded shortcuts by operation type for faster decisions.', bn: 'দ্রুত সিদ্ধান্তের জন্য অপারেশন অনুযায়ী compact shortcut।'),
              ),
              _ActionTile(icon: Icons.notifications_active_rounded, title: t('Notification Center', 'নোটিফিকেশন সেন্টার'), subtitle: t('Pending orders, push logs and activity logs', 'পেন্ডিং অর্ডার, Push log ও Activity log'), page: const NotificationCenterPage(), gradient: AppTheme.dangerGradient),
              _ActionTile(icon: Icons.shopping_bag_rounded, title: t('Orders', 'অর্ডার'), subtitle: t('View orders and update status', 'অর্ডার দেখুন ও Status update করুন'), page: const OrdersPage(), locked: isLocked('orders'), requiredPackage: 'Launch', gradient: AppTheme.premiumGradient),
              _ActionTile(icon: Icons.inventory_2_rounded, title: t('Products', 'প্রোডাক্ট'), subtitle: t('Products, images, variations and stock updates', 'প্রোডাক্ট, ছবি, Variation ও Stock update'), page: const ProductsPage(), locked: isLocked('products'), requiredPackage: 'Launch', gradient: AppTheme.infoGradient),
              _ActionTile(icon: Icons.tune_rounded, title: t('Operations', 'অপারেশন'), subtitle: t('Coupons, delivery, payments and couriers', 'Coupon, Delivery, Payment ও Courier'), page: const OperationsPage(), gradient: AppTheme.warningGradient),
              _ActionTile(icon: Icons.inventory_2_outlined, title: t('Inventory & Returns', 'Inventory & Return'), subtitle: t('Stock adjustment, warehouses and returns', 'Stock adjustment, Warehouse ও Return'), page: const InventoryManagementPage(), locked: isLocked('inventory'), requiredPackage: 'Scale', gradient: AppTheme.successGradient),
              _ActionTile(icon: Icons.insights_rounded, title: t('Reports', 'রিপোর্ট'), subtitle: t('Sales, low stock and latest orders', 'Sales, Low stock ও Latest order'), page: const ReportsPage(), locked: isLocked('advanced_reports'), requiredPackage: 'Scale', gradient: AppTheme.premiumGradient),
              _ActionTile(icon: Icons.palette_rounded, title: t('Appearance', 'Appearance'), subtitle: t('Basic theme settings and sliders', 'Basic theme setting ও Slider'), page: const AppearanceManagementPage(), locked: isLocked('theme_customization'), requiredPackage: 'Launch', gradient: AppTheme.dangerGradient),
              _ActionTile(icon: Icons.web_rounded, title: t('Content & SEO', 'Content & SEO'), subtitle: t('Pages, blog, menus and SEO fields', 'Page, blog, menu ও SEO field'), page: const ContentManagementPage(), locked: isLocked('page_builder') || isLocked('menu_builder'), requiredPackage: 'Scale', gradient: AppTheme.infoGradient),
              _ActionTile(icon: Icons.admin_panel_settings_rounded, title: t('Access Management', 'Access Management'), subtitle: t('Staff accounts and role visibility', 'Staff account ও Role visibility'), page: const AccessManagementPage(), locked: isLocked('staff_accounts'), requiredPackage: 'Scale', gradient: AppTheme.warningGradient),
              _ActionTile(icon: Icons.business_center_rounded, title: t('Business Operations', 'Business Operations'), subtitle: t('Suppliers, purchases and expenses', 'Supplier, Purchase ও Expense'), page: const BusinessManagementPage(), locked: isLocked('inventory') || isLocked('purchase_orders') || isLocked('expenses'), requiredPackage: 'Scale', gradient: AppTheme.successGradient),
              _ActionTile(icon: Icons.category_rounded, title: t('Categories', 'ক্যাটাগরি'), subtitle: t('Category image, status and home visibility', 'Category, Image ও Home visibility'), page: const CategoriesPage(), locked: isLocked('categories'), requiredPackage: 'Launch', gradient: AppTheme.infoGradient),
              _ActionTile(icon: Icons.people_alt_rounded, title: t('Customers', 'কাস্টমার'), subtitle: t('Customer details and order history', 'Customer details ও Order history'), page: const CustomersPage(), gradient: AppTheme.premiumGradient),
              _ActionTile(icon: Icons.verified_user_rounded, title: 'Push & Plan Audit', subtitle: t('Firebase, device token and plan sync check', 'Firebase, device token ও plan sync check'), page: const MobileQualityPage(), gradient: AppTheme.successGradient),
              _ActionTile(icon: Icons.delete_rounded, title: 'Trash Center', subtitle: t('Restore or delete orders and products', 'Order ও product restore/delete করুন'), page: const TrashCenterPage(), gradient: AppTheme.dangerGradient),
              _ActionTile(icon: Icons.person_rounded, title: t('My Account', 'My Account'), subtitle: t('Profile, password and active sessions', 'Profile, Password ও Active session'), page: const MyAccountPage(), gradient: AppTheme.infoGradient),
            ],
          ),
        );
      },
    );
  }
}


class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({required this.title, required this.value, required this.icon, required this.gradient, required this.caption, required this.onTap});

  final String title;
  final Object value;
  final IconData icon;
  final Gradient gradient;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 39, height: 39, decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: Colors.white, size: 20)),
                  const Spacer(),
                  Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.border)),
                    child: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.muted),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(value.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.text, height: 1)),
                  const SizedBox(height: 4),
                  Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted2, fontSize: 10.8, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedsAttentionPanel extends StatelessWidget {
  const _NeedsAttentionPanel({required this.pendingOrders, required this.unpaidOrders, required this.todaySales, required this.onPending, required this.onUnpaid, required this.onNotifications, required this.onReports});

  final int pendingOrders;
  final int unpaidOrders;
  final String todaySales;
  final VoidCallback onPending;
  final VoidCallback onUnpaid;
  final VoidCallback onNotifications;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 35, height: 35, decoration: BoxDecoration(gradient: AppTheme.warningGradient, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 19)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Needs Attention', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: AppTheme.text))),
              TextButton(onPressed: onNotifications, child: const Text('View alerts')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _AttentionButton(label: 'Pending', value: pendingOrders.toString(), icon: Icons.pending_actions_rounded, onTap: onPending)),
              const SizedBox(width: 9),
              Expanded(child: _AttentionButton(label: 'Unpaid', value: unpaidOrders.toString(), icon: Icons.payments_rounded, onTap: onUnpaid)),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _AttentionButton(label: 'Today sales', value: '৳ $todaySales', icon: Icons.insights_rounded, onTap: onReports)),
              const SizedBox(width: 9),
              Expanded(child: _AttentionButton(label: 'Alerts', value: 'Open', icon: Icons.notifications_active_rounded, onTap: onNotifications)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionButton extends StatelessWidget {
  const _AttentionButton({required this.label, required this.value, required this.icon, required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreDashboardPayload {
  const _StoreDashboardPayload({required this.dashboard, required this.meta});
  final Map<String, dynamic> dashboard;
  final AppMeta meta;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
    required this.gradient,
    this.locked = false,
    this.requiredPackage = 'a higher plan',
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  final Gradient gradient;
  final bool locked;
  final String requiredPackage;

  @override
  Widget build(BuildContext context) {
    return PremiumActionTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      gradient: gradient,
      locked: locked,
      requiredPackage: requiredPackage,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
    );
  }
}