import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_copy.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/app_mode.dart';
import '../../core/state/app_theme_controller.dart';
import '../../core/state/workspace_controller.dart';
import '../account/my_account_page.dart';
import '../auth/login_page.dart';
import '../guide/desktop_feature_guide_page.dart';
import '../portal/portal_dashboard_page.dart';
import '../portal/portal_invoices_page.dart';
import '../portal/portal_renew_page.dart';
import '../portal/portal_services_page.dart';
import '../settings/app_preferences_page.dart';
import '../store/orders_page.dart';
import '../store/products_page.dart';
import '../store/store_dashboard_page.dart';
import '../store/store_more_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  AppMode? _lastMode;
  String? _badgeToken;
  int _pendingOrders = 0;

  Future<void> _loadPendingOrderBadge(WorkspaceController workspace) async {
    final token = workspace.activeStoreToken;
    if (token == null || token.isEmpty) return;
    try {
      final response = await workspace.storeApi.pendingOrderBadge(token);
      final count = int.tryParse(response['pending_orders']?.toString() ?? '0') ?? 0;
      if (mounted) setState(() => _pendingOrders = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final themeController = context.watch<AppThemeController>();
    final preset = themeController.selectedPreset;
    final t = themeController.t;

    if (workspace.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!workspace.hasAnySession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_lastMode != workspace.activeMode) {
      _lastMode = workspace.activeMode;
      _index = 0;
    }

    if (workspace.activeMode == AppMode.store && workspace.activeStoreToken != null && _badgeToken != workspace.activeStoreToken) {
      _badgeToken = workspace.activeStoreToken;
      Future.microtask(() => _loadPendingOrderBadge(workspace));
    }
    if (workspace.activeMode == AppMode.portal && _pendingOrders != 0) _pendingOrders = 0;

    final pages = workspace.activeMode == AppMode.portal
        ? const [PortalDashboardPage(), PortalServicesPage(), PortalRenewPage(), PortalInvoicesPage(), AppPreferencesPage()]
        : const [StoreDashboardPage(), OrdersPage(), ProductsPage(), StoreMorePage(), AppPreferencesPage()];

    final destinations = workspace.activeMode == AppMode.portal
        ? [
            NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: t('Home', 'হোম')),
            NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: t('Services', 'সার্ভিস')),
            NavigationDestination(icon: const Icon(Icons.event_repeat_outlined), selectedIcon: const Icon(Icons.event_repeat), label: t('Renew', 'রিনিউ')),
            NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: t('Invoices', 'Invoice')),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: t('Settings', 'সেটিংস')),
          ]
        : [
            NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: t('Home', 'হোম')),
            NavigationDestination(icon: _BadgeIcon(icon: Icons.shopping_bag_outlined, count: _pendingOrders), selectedIcon: _BadgeIcon(icon: Icons.shopping_bag, count: _pendingOrders), label: t('Orders', 'অর্ডার')),
            NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: t('Products', 'প্রোডাক্ট')),
            NavigationDestination(icon: const Icon(Icons.more_horiz), selectedIcon: const Icon(Icons.more), label: t('More', 'আরও')),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: t('Settings', 'সেটিংস')),
          ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 10,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(gradient: preset.premiumGradient, borderRadius: BorderRadius.circular(14), boxShadow: AppTheme.softShadow),
              child: ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.asset('assets/images/app_logo.png', width: 32, height: 32)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BDS Commerce', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                  Text(workspace.activeMode == AppMode.portal ? t('Client Portal', 'Client Portal') : t('Store Admin', 'Store Admin'), style: const TextStyle(color: AppTheme.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.swap_horiz, size: 17),
              label: Text(workspace.activeMode == AppMode.portal ? 'Portal' : 'Store'),
              onPressed: () => _openSwitcher(context, workspace),
            ),
          ),
        ],
      ),
      drawer: _WorkspaceDrawer(onAddLogin: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()))),
      body: pages[_index.clamp(0, pages.length - 1)],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, destinations.length - 1),
        onDestinationSelected: (value) {
          setState(() => _index = value);
          if (workspace.activeMode == AppMode.store) _loadPendingOrderBadge(workspace);
        },
        destinations: destinations,
      ),
    );
  }

  Future<void> _openSwitcher(BuildContext context, WorkspaceController workspace) async {
    final t = context.read<AppThemeController>().t;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Switch workspace', 'Workspace পরিবর্তন'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _SwitchTile(mode: AppMode.portal, title: 'Client Portal', subtitle: t('Billing, services and notifications', 'Billing, Service ও Notification'), enabled: workspace.hasPortalSession),
              _SwitchTile(mode: AppMode.store, title: workspace.activeStoreSlug ?? 'Store Admin', subtitle: t('Orders, products and store settings', 'Order, Product ও Store setting'), enabled: workspace.hasStoreSession),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
                },
                icon: const Icon(Icons.add),
                label: Text(t('Add another login', 'আরেকটি Login যোগ করুন')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Badge(label: Text(count > 99 ? '99+' : count.toString()), child: Icon(icon));
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.mode, required this.title, required this.subtitle, required this.enabled});
  final AppMode mode;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final selected = workspace.activeMode == mode;
    final t = context.watch<AppThemeController>().t;
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(mode == AppMode.portal ? Icons.receipt_long : Icons.storefront, color: enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(enabled ? subtitle : t('Login required', 'Login দরকার')),
        trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
        enabled: enabled,
        onTap: () async {
          await context.read<WorkspaceController>().switchMode(mode);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _WorkspaceDrawer extends StatefulWidget {
  const _WorkspaceDrawer({required this.onAddLogin});
  final VoidCallback onAddLogin;

  @override
  State<_WorkspaceDrawer> createState() => _WorkspaceDrawerState();
}

class _WorkspaceDrawerState extends State<_WorkspaceDrawer> {
  AppMeta? _meta;
  bool _loadingMeta = false;

  Future<AppMeta> _loadMeta(WorkspaceController workspace) async {
    if (_meta != null) return _meta!;
    if (_loadingMeta) return const AppMeta(copy: AppCopy(<String, dynamic>{}), support: <String, dynamic>{});
    _loadingMeta = true;
    try {
      _meta = await AppMeta.load(workspace);
      return _meta!;
    } finally {
      _loadingMeta = false;
    }
  }

  Future<void> _call(WorkspaceController workspace) async {
    final t = context.read<AppThemeController>().t;
    final meta = await _loadMeta(workspace);
    final phone = meta.support['phone']?.toString().trim() ?? '';
    if (phone.isEmpty) return _toast(t('Emergency phone is not configured yet.', 'Emergency phone এখনো set করা নেই।'));
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open the phone dialer.', 'Phone dialer open করা যায়নি।'));
  }

  Future<void> _whatsapp(WorkspaceController workspace) async {
    final t = context.read<AppThemeController>().t;
    final meta = await _loadMeta(workspace);
    final number = (meta.support['whatsapp']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final message = meta.support['message']?.toString() ?? 'Need urgent help with my BDS Commerce account.';
    if (number.isEmpty) return _toast(t('WhatsApp number is not configured yet.', 'WhatsApp number এখনো set করা নেই।'));
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open WhatsApp.', 'WhatsApp open করা যায়নি।'));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final theme = context.watch<AppThemeController>();
    final preset = theme.selectedPreset;
    final lang = theme.language;
    final t = theme.t;
    return Drawer(
      width: 286,
      child: SafeArea(
        child: FutureBuilder<AppMeta>(
          future: _loadMeta(workspace),
          builder: (context, snapshot) {
            final copy = snapshot.data?.copy ?? const AppCopy(<String, dynamic>{});
            return ListView(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 12),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: preset.heroGradient, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.glowShadow(preset.key)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
                        child: Image.asset('assets/images/app_logo.png', width: 40, height: 40),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BDS Commerce', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                            Text(workspace.activeMode == AppMode.portal ? 'Client Portal' : 'Store Admin', style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _DrawerAction(icon: Icons.receipt_long, title: 'Client Portal', selected: workspace.activeMode == AppMode.portal, enabled: workspace.hasPortalSession, onTap: () => workspace.switchMode(AppMode.portal)),
                _DrawerAction(icon: Icons.storefront, title: workspace.activeStoreSlug ?? 'Store Admin', selected: workspace.activeMode == AppMode.store, enabled: workspace.hasStoreSession, onTap: () => workspace.switchMode(AppMode.store)),
                const SizedBox(height: 4),
                _DrawerAction(
                  icon: Icons.desktop_windows_rounded,
                  title: copy.localized(lang, 'drawer_desktop_guide', en: 'Desktop Feature Guide', bn: 'Desktop Feature Guide'),
                  subtitle: copy.localized(lang, 'drawer_desktop_guide_subtitle', en: 'Mobile coverage and desktop-only features', bn: 'Mobile coverage এবং Desktop-only features'),
                  color: AppTheme.secondary,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesktopFeatureGuidePage())),
                ),
                _DrawerAction(
                  icon: Icons.call_rounded,
                  title: copy.localized(lang, 'drawer_emergency_call', en: 'Emergency Call', bn: 'Emergency Call'),
                  subtitle: copy.localized(lang, 'drawer_emergency_call_subtitle', en: 'Direct SaaS support call', bn: 'Direct SaaS support call'),
                  color: AppTheme.success,
                  onTap: () => _call(workspace),
                ),
                _DrawerAction(
                  icon: Icons.chat_rounded,
                  title: copy.localized(lang, 'drawer_whatsapp_support', en: 'WhatsApp Support', bn: 'WhatsApp Support'),
                  subtitle: copy.localized(lang, 'drawer_whatsapp_support_subtitle', en: 'Open urgent support chat', bn: 'Urgent support chat open করুন'),
                  color: const Color(0xFF25D366),
                  onTap: () => _whatsapp(workspace),
                ),
                const Divider(height: 18),
                _DrawerAction(icon: Icons.person_outline, title: t('My Account', 'My Account'), enabled: workspace.hasAnySession, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyAccountPage()))),
                _DrawerAction(icon: Icons.add, title: t('Add another login', 'আরেকটি Login যোগ করুন'), onTap: widget.onAddLogin),
                _DrawerAction(
                  icon: Icons.logout,
                  title: t('Logout active mode', 'Active mode logout'),
                  color: AppTheme.danger,
                  onTap: () async {
                    final workspace = context.read<WorkspaceController>();
                    Navigator.of(context).pop();
                    await workspace.logoutActive();
                    if (context.mounted && !workspace.hasAnySession) {
                      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  const _DrawerAction({required this.icon, required this.title, this.subtitle, this.onTap, this.selected = false, this.enabled = true, this.color = AppTheme.primary});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? color.withOpacity(0.10) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? color.withOpacity(0.30) : AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          horizontalTitleGap: 8,
          minLeadingWidth: 30,
          enabled: enabled,
          leading: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withOpacity(enabled ? 0.11 : 0.04), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: enabled ? color : AppTheme.muted2, size: 17),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.8, color: AppTheme.muted, fontWeight: FontWeight.w400)),
          trailing: selected ? Icon(Icons.check_circle_rounded, color: color, size: 20) : const Icon(Icons.chevron_right_rounded, color: AppTheme.muted2, size: 20),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}
