import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_copy.dart';
import '../../core/config/app_language.dart';
import '../../core/config/app_theme.dart';
import '../../core/state/app_theme_controller.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/premium_widgets.dart';

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
    if (cleaned.isEmpty) return _toast(t('Emergency phone is not configured yet.', 'Emergency phone এখনো set করা নেই।'));
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open the phone dialer.', 'Phone dialer open করা যায়নি।'));
  }

  Future<void> _whatsapp(String number, String message) async {
    final t = context.read<AppThemeController>().t;
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return _toast(t('WhatsApp number is not configured yet.', 'WhatsApp number এখনো set করা নেই।'));
    final uri = Uri.parse('https://wa.me/$cleaned?text=${Uri.encodeComponent(message.isEmpty ? 'Need urgent help with my BDS Commerce account.' : message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open WhatsApp.', 'WhatsApp open করা যায়নি।'));
  }

  Future<void> _openDesktop(String url) async {
    final t = context.read<AppThemeController>().t;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return _toast(t('Desktop admin URL is not configured yet.', 'Desktop admin URL এখনো set করা নেই।'));
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) _toast(t('Could not open Desktop Admin URL.', 'Desktop Admin URL open করা যায়নি।'));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeController>();
    final lang = theme.language;
    return Scaffold(
      appBar: AppBar(title: Text(theme.t('Desktop Feature Guide', 'Desktop Feature Guide'))),
      body: FutureBuilder<AppMeta>(
        future: _metaFuture,
        builder: (context, snapshot) {
          final meta = snapshot.data ?? const AppMeta(copy: AppCopy(<String, dynamic>{}), support: <String, dynamic>{});
          final copy = meta.copy;
          final support = meta.support;
          final phone = support['phone']?.toString() ?? '';
          final whatsapp = support['whatsapp']?.toString() ?? '';
          final hours = support['hours']?.toString() ?? theme.t('Support hours', 'Support সময়');
          final message = support['message']?.toString() ?? 'Need urgent help with my BDS Commerce account.';
          final desktopUrl = support['desktop_admin_url']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.all(15),
            children: [
              PremiumHeroCard(
                title: copy.localized(lang, 'guide_hero_title', en: 'Mobile for daily actions. Desktop for full control.', bn: 'দৈনিক কাজ Mobile app-এ, full control Desktop admin-এ।'),
                subtitle: copy.localized(lang, 'guide_hero_subtitle', en: 'The app is optimized for quick store and portal operations. Advanced setup, bulk work and design-heavy tasks are best handled from desktop admin.', bn: 'App quick Store/Portal operation-এর জন্য। Advanced setup, bulk work ও design-heavy কাজ Desktop admin-এ করা best।'),
                icon: Icons.workspace_premium_rounded,
                badge: copy.localized(lang, 'guide_badge', en: 'Premium UX', bn: 'Premium UX'),
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primary),
                  onPressed: () => _openDesktop(desktopUrl),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(copy.localized(lang, 'guide_open_desktop_button', en: 'Open Desktop Admin', bn: 'Desktop Admin খুলুন')),
                ),
              ),
              const SizedBox(height: 18),
              PremiumSectionTitle(
                title: copy.localized(lang, 'guide_mobile_section_title', en: 'Available in mobile app', bn: 'Mobile app-এ available'),
                subtitle: copy.localized(lang, 'guide_mobile_section_subtitle', en: 'Fast actions for daily store and portal management.', bn: 'Daily Store ও Portal management-এর quick action.'),
              ),
              ..._mobileFeatures.map((item) => _FeatureRow(item: item, enabled: true, language: lang)),
              const SizedBox(height: 12),
              PremiumSectionTitle(
                title: copy.localized(lang, 'guide_desktop_section_title', en: 'Use desktop admin for these', bn: 'এই কাজগুলো Desktop admin-এ করুন'),
                subtitle: copy.localized(lang, 'guide_desktop_section_subtitle', en: 'These features are not hidden. Desktop workflow is recommended for full, safe control.', bn: 'Features লুকানো না — full, safe control-এর জন্য Desktop workflow recommended.'),
              ),
              ..._desktopOnlyFeatures.map((item) => _FeatureRow(item: item, enabled: false, language: lang)),
              const SizedBox(height: 16),
              PremiumSectionTitle(title: copy.localized(lang, 'guide_support_title', en: 'Emergency support', bn: 'Emergency support'), subtitle: hours),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.localized(lang, 'guide_support_card_title', en: 'Need quick help?', bn: 'দ্রুত help দরকার?'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
                    const SizedBox(height: 6),
                    Text(copy.localized(lang, 'guide_support_card_subtitle', en: 'Call or WhatsApp support directly. These contacts are controlled from SaaS admin settings.', bn: 'Call বা WhatsApp দিয়ে direct support নিন। Number SaaS admin settings থেকে controlled.'), style: const TextStyle(color: AppTheme.muted, height: 1.42, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppTheme.success), onPressed: () => _call(phone), icon: const Icon(Icons.call_rounded), label: Text(copy.localized(lang, 'guide_call_button', en: 'Call', bn: 'Call')))),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)), onPressed: () => _whatsapp(whatsapp, message), icon: const Icon(Icons.chat_rounded), label: Text(copy.localized(lang, 'guide_whatsapp_button', en: 'WhatsApp', bn: 'WhatsApp')))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          );
        },
      ),
    );
  }
}

class _GuideItem {
  const _GuideItem(this.icon, this.titleEn, this.titleBn, this.subtitleEn, this.subtitleBn);
  final IconData icon;
  final String titleEn;
  final String titleBn;
  final String subtitleEn;
  final String subtitleBn;
}

const _mobileFeatures = <_GuideItem>[
  _GuideItem(Icons.shopping_bag_rounded, 'Orders & status updates', 'অর্ডার ও Status update', 'View orders, update status and track pending orders.', 'অর্ডার দেখুন, Status update করুন ও Pending order track করুন।'),
  _GuideItem(Icons.inventory_2_rounded, 'Products & stock quick actions', 'প্রোডাক্ট ও Stock quick action', 'Create/edit products, images, variations and quick stock updates.', 'প্রোডাক্ট, ছবি, Variation ও quick Stock update।'),
  _GuideItem(Icons.local_offer_rounded, 'Coupons, delivery and payments', 'Coupon, Delivery ও Payment', 'Manage daily operations without opening desktop.', 'Desktop না খুলেই daily operation manage করুন।'),
  _GuideItem(Icons.notifications_active_rounded, 'Notifications and push logs', 'Notification ও Push log', 'Review store alerts, plan audit and push status.', 'Store alert, Plan audit ও Push status দেখুন।'),
  _GuideItem(Icons.receipt_long_rounded, 'Client Portal billing', 'Client Portal billing', 'Invoices, renewals, services and support tickets.', 'Invoice, Renewal, Service ও Support ticket.'),
  _GuideItem(Icons.support_agent_rounded, 'Support ticket workflow', 'Support ticket workflow', 'Create tickets, reply and track service issues.', 'Ticket create, Reply ও Service issue track করুন।'),
];

const _desktopOnlyFeatures = <_GuideItem>[
  _GuideItem(Icons.query_stats_rounded, 'Advanced report ও Export', 'Advanced report ও Export', 'Deep analytics, date range, CSV/export and accounting workflow.', 'Deep analytics, Date range, CSV/Export ও Accounting workflow.'),
  _GuideItem(Icons.palette_rounded, 'Theme, Page ও Menu builder', 'Theme, Page ও Menu builder', 'Storefront layout, homepage section, menu, SEO and design-heavy edit.', 'Storefront layout, Homepage section, Menu, SEO ও design-heavy edit.'),
  _GuideItem(Icons.account_tree_rounded, 'Funnel ও Automation setup', 'Funnel ও Automation setup', 'Marketing funnel, Google Sheets automation and complex integrations.', 'Marketing funnel, Google Sheets automation ও complex integration.'),
  _GuideItem(Icons.admin_panel_settings_rounded, 'Deep staff role permission', 'Deep staff role permission', 'Fine-grained permission matrix, audit review and security policy.', 'Fine-grained permission matrix, Audit review ও Security policy.'),
  _GuideItem(Icons.warehouse_rounded, 'Bulk inventory operation', 'Bulk inventory operation', 'Bulk import/export, warehouse transfer and large adjustment job.', 'Bulk import/export, Warehouse transfer ও large adjustment job.'),
  _GuideItem(Icons.shield_rounded, 'Fraud checker ও Advanced courier setup', 'Fraud checker ও Advanced courier setup', 'Provider-level settings, fraud tools and courier rule configuration.', 'Provider-level settings, Fraud tools ও Courier rule configuration.'),
  _GuideItem(Icons.settings_applications_rounded, 'System-level configuration', 'System-level configuration', 'Payment gateway credentials, DNS/domain, backup and release operations.', 'Payment gateway credentials, DNS/domain, Backup ও Release operation.'),
  _GuideItem(Icons.desktop_windows_rounded, 'Bulk content management', 'Bulk content management', 'Blog/page mass edits, media library cleanup and advanced SEO metadata.', 'Blog/page mass edits, Media library cleanup ও advanced SEO metadata.'),
];

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.item, required this.enabled, required this.language});
  final _GuideItem item;
  final bool enabled;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final gradient = enabled ? AppTheme.successGradient : AppTheme.warningGradient;
    return PremiumActionTile(
      icon: item.icon,
      title: language.isBangla ? item.titleBn : item.titleEn,
      subtitle: language.isBangla ? item.subtitleBn : item.subtitleEn,
      gradient: gradient,
      badge: enabled ? 'APP' : 'DESKTOP',
      trailing: Icon(enabled ? Icons.check_circle_rounded : Icons.desktop_windows_rounded, color: enabled ? AppTheme.success : AppTheme.warning),
    );
  }
}
