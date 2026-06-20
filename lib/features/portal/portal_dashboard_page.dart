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

  String _getGreeting(dynamic lang) {
    final hour = DateTime.now().hour;
    final isBn = lang.toString().contains('bn');
    if (hour < 12) return isBn ? 'শুভ সকাল' : 'Good Morning';
    if (hour < 17) return isBn ? 'শুভ অপরাহ্ন' : 'Good Afternoon';
    return isBn ? 'শুভ সন্ধ্যা' : 'Good Evening';
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
                            copy.localized(lang, 'portal_dashboard_title', en: 'Client Portal', bn: 'Client Portal'),
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
                      tooltip: copy.localized(lang, 'portal_dashboard_guide_button', en: 'Desktop Guide', bn: 'Desktop Guide'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              _MetricGrid(summary: summary),
              const SizedBox(height: 24),
              
              PremiumSectionTitle(
                title: copy.localized(lang, 'portal_actions_title', en: 'Quick Actions', bn: 'দ্রুত অ্যাকশন'),
                subtitle: copy.localized(lang, 'portal_actions_subtitle', en: 'Shortcuts for the daily portal workflow.', bn: 'Daily Portal workflow-এর জন্য shortcut।'),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4, 
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [
                  _GridActionTile(icon: Icons.receipt_long_rounded, title: t('Billing', 'Billing'), page: const PortalBillingCenterPage(), gradient: AppTheme.premiumGradient),
                  _GridActionTile(icon: Icons.event_repeat_rounded, title: t('Renewal', 'Renewal'), page: const PortalRenewalCenterPage(), gradient: AppTheme.warningGradient),
                  _GridActionTile(icon: Icons.storefront_rounded, title: t('Services', 'সার্ভিস'), page: const PortalServicesPage(), gradient: AppTheme.infoGradient),
                  _GridActionTile(icon: Icons.payments_rounded, title: t('Local Bill', 'Local Bill'), page: const PortalLocalBillingPage(), gradient: AppTheme.successGradient),
                  _GridActionTile(icon: Icons.notifications_active_rounded, title: t('Alerts', 'Alerts'), page: const PortalNotificationsPage(), gradient: AppTheme.dangerGradient),
                  _GridActionTile(icon: Icons.support_agent_rounded, title: t('Support', 'Support'), page: const PortalSupportPage(), gradient: AppTheme.premiumGradient),
                  _GridActionTile(icon: Icons.task_alt_rounded, title: t('Onboarding', 'Onboard'), page: const PortalOnboardingPage(), gradient: AppTheme.successGradient),
                  _GridActionTile(icon: Icons.person_rounded, title: t('Account', 'Account'), page: const MyAccountPage(), gradient: AppTheme.infoGradient),
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

class _GridActionTile extends StatelessWidget {
  const _GridActionTile({
    required this.icon,
    required this.title,
    required this.page,
    required this.gradient,
  }); // <-- completely removed "locked" logic

  final IconData icon;
  final String title;
  final Widget page;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}