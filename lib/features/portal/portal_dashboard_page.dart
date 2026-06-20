import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_copy.dart';
import '../../core/config/app_theme.dart';
import '../../core/state/app_theme_controller.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/premium_widgets.dart';
import '../../shared/widgets/renewal_warning_banner.dart';
import '../account/my_account_page.dart';
import '../guide/desktop_feature_guide_page.dart';
import 'portal_billing_center_page.dart';
import 'portal_local_billing_page.dart';
import 'portal_notifications_page.dart';
import 'portal_onboarding_page.dart';
import 'portal_renew_page.dart';
import 'portal_renewal_center_page.dart';
import 'portal_services_page.dart';
import 'portal_support_page.dart';

class PortalDashboardPage extends StatefulWidget {
  const PortalDashboardPage({super.key});

  @override
  State<PortalDashboardPage> createState() => _PortalDashboardPageState();
}

class _PortalDashboardPageState extends State<PortalDashboardPage> {
  late Future<_PortalDashboardPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PortalDashboardPayload> _load() async {
    final workspace = context.read<WorkspaceController>();
    final dashboard = await workspace.portalApi.dashboard(workspace.portalToken!);
    final meta = await AppMeta.load(workspace);
    return _PortalDashboardPayload(dashboard: dashboard, meta: meta);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeController>();
    final lang = theme.language;
    final t = theme.t;
    return FutureBuilder<_PortalDashboardPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        final payload = snapshot.data!;
        final data = payload.dashboard;
        final copy = payload.meta.copy;
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: [
              RenewalWarningBanner(
                payload: data,
                copy: copy,
                onRenewNow: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PortalRenewPage())),
              ),
              PremiumHeroCard(
                title: copy.localized(lang, 'portal_dashboard_title', en: 'Client Portal', bn: 'Client Portal'),
                subtitle: copy.localized(lang, 'portal_dashboard_subtitle', en: 'Premium control center for services, billing, renewals, notifications and support.', bn: 'সার্ভিস, Billing, Renewal, Notification ও Support দ্রুত manage করার premium control center।'),
                icon: Icons.workspace_premium_rounded,
                badge: copy.localized(lang, 'portal_dashboard_badge', en: 'Client Portal', bn: 'Client Portal'),
                action: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.30))),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesktopFeatureGuidePage())),
                  icon: const Icon(Icons.desktop_windows_rounded),
                  label: Text(copy.localized(lang, 'portal_dashboard_guide_button', en: 'App vs Desktop Guide', bn: 'App vs Desktop Guide')),
                ),
              ),
              const SizedBox(height: 16),
              _MetricGrid(summary: summary),
              const SizedBox(height: 18),
              PremiumSectionTitle(
                title: copy.localized(lang, 'portal_actions_title', en: 'Client actions', bn: 'ক্লায়েন্ট অ্যাকশন'),
                subtitle: copy.localized(lang, 'portal_actions_subtitle', en: 'Quick, colorful shortcuts for the daily portal workflow.', bn: 'Daily Portal workflow-এর জন্য compact shortcut।'),
              ),
              _NavCard(title: t('Billing Center', 'Billing Center'), subtitle: t('Invoices, payments and package requests', 'Invoice, Payment ও Package request'), icon: Icons.receipt_long_rounded, page: const PortalBillingCenterPage(), gradient: AppTheme.premiumGradient),
              _NavCard(title: t('Renewal Center', 'Renewal Center'), subtitle: t('Renewal dates, reminders and renewal support', 'Renewal date, Reminder ও Support'), icon: Icons.event_repeat_rounded, page: const PortalRenewalCenterPage(), gradient: AppTheme.warningGradient),
              _NavCard(title: t('Services', 'সার্ভিস'), subtitle: t('Active services and details', 'Active service ও Details'), icon: Icons.storefront_rounded, page: const PortalServicesPage(), gradient: AppTheme.infoGradient),
              _NavCard(title: t('Local Billing', 'Local Billing'), subtitle: t('Local invoices and payment status', 'Local invoice ও Payment status'), icon: Icons.payments_rounded, page: const PortalLocalBillingPage(), gradient: AppTheme.successGradient),
              _NavCard(title: t('Notifications', 'Notifications'), subtitle: t('Alerts, reminders and updates', 'Alert, Reminder ও Update'), icon: Icons.notifications_active_rounded, page: const PortalNotificationsPage(), gradient: AppTheme.dangerGradient),
              _NavCard(title: t('Support', 'Support'), subtitle: t('Create tickets and track replies', 'Ticket create ও Reply track করুন'), icon: Icons.support_agent_rounded, page: const PortalSupportPage(), gradient: AppTheme.premiumGradient),
              _NavCard(title: t('Onboarding', 'Onboarding'), subtitle: t('Submit setup information and files', 'Setup info ও File submit করুন'), icon: Icons.task_alt_rounded, page: const PortalOnboardingPage(), gradient: AppTheme.successGradient),
              _NavCard(title: t('My Account', 'My Account'), subtitle: t('Profile, password and sessions', 'Profile, Password ও Session'), icon: Icons.person_rounded, page: const MyAccountPage(), gradient: AppTheme.infoGradient),
              _NavCard(title: t('Desktop Guide', 'Desktop Guide'), subtitle: t('Mobile features and desktop recommended features', 'Mobile feature এবং Desktop recommended feature'), icon: Icons.desktop_windows_rounded, page: const DesktopFeatureGuidePage(), gradient: AppTheme.warningGradient),
            ],
          ),
        );
      },
    );
  }
}

class _PortalDashboardPayload {
  const _PortalDashboardPayload({required this.dashboard, required this.meta});
  final Map<String, dynamic> dashboard;
  final AppMeta meta;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppThemeController>().t;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.15,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        PremiumMetricCard(title: t('Services', 'সার্ভিস'), value: summary['services'] ?? summary['total_services'] ?? 0, icon: Icons.storefront_rounded, gradient: AppTheme.premiumGradient, caption: t('Total services', 'মোট সার্ভিস')),
        PremiumMetricCard(title: t('Active', 'Active'), value: summary['active_services'] ?? summary['active'] ?? 0, icon: Icons.verified_rounded, gradient: AppTheme.successGradient, caption: t('Running now', 'এখন চালু')),
        PremiumMetricCard(title: t('Unpaid', 'Unpaid'), value: summary['unpaid_invoices'] ?? summary['unpaid'] ?? 0, icon: Icons.receipt_long_rounded, gradient: AppTheme.warningGradient, caption: t('Needs payment', 'পেমেন্ট দরকার')),
        PremiumMetricCard(title: t('Unread', 'Unread'), value: summary['unread_notifications'] ?? summary['unread'] ?? 0, icon: Icons.notifications_active_rounded, gradient: AppTheme.dangerGradient, caption: t('New alerts', 'নতুন Alert')),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.title, required this.subtitle, required this.icon, required this.page, required this.gradient});
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return PremiumActionTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      gradient: gradient,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
    );
  }
}
