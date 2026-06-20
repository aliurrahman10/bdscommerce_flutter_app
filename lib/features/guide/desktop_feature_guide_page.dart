import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_copy.dart';
import '../../core/config/app_theme.dart';
import '../../core/state/app_theme_controller.dart';
import '../../core/state/workspace_controller.dart';

class DesktopFeatureGuidePage extends StatefulWidget {
  const DesktopFeatureGuidePage({super.key});

  @override
  State<DesktopFeatureGuidePage> createState() => _DesktopFeatureGuidePageState();
}

class _DesktopFeatureGuidePageState extends State<DesktopFeatureGuidePage> {
  late Future<AppMeta> _metaFuture;

  @override
  void initState() {
    super.initState();
    _metaFuture = AppMeta.load(context.read<WorkspaceController>());
  }

  Future<void> _call(String phone) async {
    final t = context.read<AppThemeController>().t;
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return _toast(t('Emergency phone is not configured yet.', 'Emergency phone is not configured yet.'));
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open the phone dialer.', 'Could not open the phone dialer.'));
  }

  Future<void> _whatsapp(String number, String message) async {
    final t = context.read<AppThemeController>().t;
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return _toast(t('WhatsApp number is not configured yet.', 'WhatsApp number is not configured yet.'));
    final uri = Uri.parse('https://wa.me/$cleaned?text=${Uri.encodeComponent(message.isEmpty ? 'Need urgent help with my BDS Commerce account.' : message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open WhatsApp.', 'Could not open WhatsApp.'));
  }

  Future<void> _openDesktop(String url) async {
    final t = context.read<AppThemeController>().t;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return _toast(t('Desktop admin URL is not configured yet.', 'Desktop admin URL is not configured yet.'));
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open Desktop Admin URL.', 'Could not open Desktop Admin URL.'));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeController>();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Feature Guide', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<AppMeta>(
        future: _metaFuture,
        builder: (context, snapshot) {
          final meta = snapshot.data ?? const AppMeta(copy: AppCopy(<String, dynamic>{}), support: <String, dynamic>{});
          final support = meta.support;
          final phone = support['phone']?.toString() ?? '';
          final whatsapp = support['whatsapp']?.toString() ?? '';
          final hours = support['hours']?.toString() ?? theme.t('Support hours', 'Support hours');
          final message = support['message']?.toString() ?? 'Need urgent help with my BDS Commerce account.';
          final desktopUrl = support['desktop_admin_url']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: theme.selectedPreset.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: theme.selectedPreset.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    const Text('Mobile for daily actions. Desktop for full control.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Advanced setup, bulk work and design tasks are best handled on desktop.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: theme.selectedPreset.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      onPressed: () => _openDesktop(desktopUrl),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open Desktop Admin'),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const _Title('Available in mobile app', AppTheme.success),
              ..._mobileFeatures.map((item) => _FeatureTile(item: item, enabled: true)),
              
              const SizedBox(height: 24),
              const _Title('Desktop workflow', AppTheme.primary),
              ..._desktopOnlyFeatures.map((item) => _FeatureTile(item: item, enabled: false)),
              
              const SizedBox(height: 24),
              const _Title('Support & Help', AppTheme.muted2),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
                child: Column(
                  children: [
                    Text(hours, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: AppTheme.success, side: const BorderSide(color: AppTheme.success)), onPressed: () => _call(phone), icon: const Icon(Icons.call_rounded), label: const Text('Call'))),
                        const SizedBox(width: 12),
                        Expanded(child: FilledButton.icon(style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFF25D366)), onPressed: () => _whatsapp(whatsapp, message), icon: const Icon(Icons.chat_rounded), label: const Text('WhatsApp'))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String title;
  final Color color;
  const _Title(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title.toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item, required this.enabled});
  final _GuideItem item;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (enabled ? AppTheme.success : AppTheme.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(item.icon, color: enabled ? AppTheme.success : AppTheme.primary),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        trailing: Icon(enabled ? Icons.check_circle_rounded : Icons.desktop_windows_rounded, size: 20, color: enabled ? AppTheme.success : AppTheme.muted),
      ),
    );
  }
}

class _GuideItem {
  const _GuideItem(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

const _mobileFeatures = <_GuideItem>[
  _GuideItem(Icons.shopping_bag_rounded, 'Orders & Status Updates', 'View orders, update status and track pending orders.'),
  _GuideItem(Icons.inventory_2_rounded, 'Products & Stock', 'Create/edit products, images, variations and quick stock updates.'),
  _GuideItem(Icons.local_offer_rounded, 'Coupons & Payments', 'Manage daily operations without opening desktop.'),
  _GuideItem(Icons.receipt_long_rounded, 'Client Portal Billing', 'Invoices, renewals, services and support tickets.'),
];

const _desktopOnlyFeatures = <_GuideItem>[
  _GuideItem(Icons.query_stats_rounded, 'Advanced Report & Export', 'Deep analytics, date range, CSV/export and accounting workflow.'),
  _GuideItem(Icons.palette_rounded, 'Theme, Page & Menu Builder', 'Storefront layout, homepage section, menu, SEO and design-heavy edit.'),
  _GuideItem(Icons.account_tree_rounded, 'Funnel & Automation Setup', 'Marketing funnel, Google Sheets automation and complex integrations.'),
  _GuideItem(Icons.admin_panel_settings_rounded, 'Staff Role Permissions', 'Fine-grained permission matrix, audit review and security policy.'),
  _GuideItem(Icons.warehouse_rounded, 'Bulk Inventory Operation', 'Bulk import/export, warehouse transfer and large adjustment job.'),
  _GuideItem(Icons.shield_rounded, 'Fraud Checker & Setup', 'Provider-level settings, fraud tools and courier rule configuration.'),
  _GuideItem(Icons.settings_applications_rounded, 'System Configuration', 'Payment gateway credentials, DNS/domain, backup and release operations.'),
  _GuideItem(Icons.desktop_windows_rounded, 'Bulk Content Management', 'Blog/page mass edits, media library cleanup and advanced SEO metadata.'),
];