import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_copy.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/app_mode.dart';
import '../../core/state/app_theme_controller.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/premium_widgets.dart';
import '../../shared/widgets/renewal_warning_banner.dart';
import '../guide/desktop_feature_guide_page.dart';
import '../portal/portal_renew_page.dart';
import 'access_management_page.dart';
import 'appearance_management_page.dart';
import 'business_management_page.dart';
import 'categories_page.dart';
import 'content_management_page.dart';
import 'customers_page.dart';
import 'inventory_management_page.dart';
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

  String _getGreeting(dynamic lang) {
    final hour = DateTime.now().hour;
    final isBn = lang.toString().contains('bn');
    if (hour < 12) return isBn ? 'শুভ সকাল' : 'Good Morning';
    if (hour < 17) return isBn ? 'শুভ অপরাহ্ন' : 'Good Afternoon';
    return isBn ? 'শুভ সন্ধ্যা' : 'Good Evening';
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
              
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting(lang)},',
                            style: const TextStyle(fontSize: 14, color: AppTheme.muted, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            workspace.activeStoreSlug ?? 'Store Admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, color: AppTheme.text, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: AppTheme.border.withOpacity(0.5)),
                      icon: const Icon(Icons.desktop_windows_rounded, color: AppTheme.primary, size: 20),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesktopFeatureGuidePage())),
                      tooltip: copy.localized(lang, 'store_dashboard_guide_button', en: 'Desktop Guide', bn: 'Desktop Guide'),
                    ),
                  ],
                ),
              ),

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
              
              const SizedBox(height: 24),
              PremiumSectionTitle(
                title: copy.localized(lang, 'store_actions_title', en: 'Quick Actions', bn: 'দ্রুত অ্যাকশন'),
                subtitle: copy.localized(lang, 'store_actions_subtitle', en: 'Manage your entire store from here.', bn: 'এখান থেকে আপনার স্টোর ম্যানেজ করুন।'),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4, // 4-Column Grid
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [
                  _GridActionTile(icon: Icons.shopping_bag_rounded, title: t('Orders', 'অর্ডার'), page: const OrdersPage(), locked: isLocked('orders'), gradient: AppTheme.premiumGradient),
                  _GridActionTile(icon: Icons.inventory_2_rounded, title: t('Products', 'প্রোডাক্ট'), page: const ProductsPage(), locked: isLocked('products'), gradient: AppTheme.infoGradient),
                  _GridActionTile(icon: Icons.category_rounded, title: t('Categories', 'ক্যাটাগরি'), page: const CategoriesPage(), locked: isLocked('categories'), gradient: AppTheme.infoGradient),
                  _GridActionTile(icon: Icons.tune_rounded, title: t('Operations', 'অপারেশন'), page: const OperationsPage(), gradient: AppTheme.warningGradient),
                  _GridActionTile(icon: Icons.insights_rounded, title: t('Reports', 'রিপোর্ট'), page: const ReportsPage(), locked: isLocked('advanced_reports'), gradient: AppTheme.premiumGradient),
                  _GridActionTile(icon: Icons.people_alt_rounded, title: t('Customers', 'কাস্টমার'), page: const CustomersPage(), gradient: AppTheme.premiumGradient),
                  _GridActionTile(icon: Icons.inventory_2_outlined, title: t('Inventory', 'Inventory'), page: const InventoryManagementPage(), locked: isLocked('inventory'), gradient: AppTheme.successGradient),
                  _GridActionTile(icon: Icons.business_center_rounded, title: t('Business', 'Business'), page: const BusinessManagementPage(), locked: isLocked('expenses'), gradient: AppTheme.successGradient),
                  _GridActionTile(icon: Icons.admin_panel_settings_rounded, title: t('Access', 'Access'), page: const AccessManagementPage(), locked: isLocked('staff_accounts'), gradient: AppTheme.warningGradient),
                  _GridActionTile(icon: Icons.palette_rounded, title: t('Appearance', 'Theme'), page: const AppearanceManagementPage(), locked: isLocked('theme_customization'), gradient: AppTheme.dangerGradient),
                  _GridActionTile(icon: Icons.web_rounded, title: t('Content', 'Content'), page: const ContentManagementPage(), locked: isLocked('page_builder'), gradient: AppTheme.infoGradient),
                  _GridActionTile(icon: Icons.delete_rounded, title: t('Trash', 'Trash'), page: const TrashCenterPage(), gradient: AppTheme.dangerGradient),
                ],
              ),
              const SizedBox(height: 20),
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
                    decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.border)),
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

class _GridActionTile extends StatelessWidget {
  const _GridActionTile({
    required this.icon,
    required this.title,
    required this.page,
    required this.gradient,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final Widget page;
  final Gradient gradient;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!locked) Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8), // Icon padding reduced for 4-columns
                      decoration: BoxDecoration(
                        gradient: locked ? null : gradient,
                        color: locked ? AppTheme.border : null,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: locked ? AppTheme.muted : Colors.white, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: locked ? AppTheme.muted : AppTheme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5, // Text size reduced for 4-columns
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.lock_rounded, size: 12, color: AppTheme.muted2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}