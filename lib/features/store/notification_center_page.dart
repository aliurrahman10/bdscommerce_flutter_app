import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/locked_feature.dart';
import 'audit_logs_page.dart';
import 'orders_page.dart';
import 'push_logs_page.dart';
import 'system_alerts_page.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.notificationCenter(workspace.activeStoreToken!);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
            final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
            final alerts = ((snapshot.data?['alerts'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
            final auditLocked = features['audit_logs'] == false;
            return Scrollbar(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 26 + bottomSafe),
                children: [
                  _StoreAlertHero(summary: summary),
                  const SizedBox(height: 16),
                  _MetricGrid(summary: summary),
                  const SizedBox(height: 16),
                  _Tile(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Pending Orders',
                    subtitle: '${summary['pending_orders'] ?? 0} pending orders need attention',
                    page: const OrdersPage(initialStatus: 'pending'),
                    locked: false,
                  ),
                  _Tile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push Notification Logs',
                    subtitle: 'Sent, failed and unread push history',
                    page: const PushLogsPage(),
                    locked: false,
                  ),
                  _Tile(
                    icon: Icons.history_outlined,
                    title: 'Activity / Audit Logs',
                    subtitle: 'Who changed what across store modules',
                    page: const AuditLogsPage(),
                    locked: auditLocked,
                  ),
                  _Tile(
                    icon: Icons.warning_amber_outlined,
                    title: 'System & Plan Alerts',
                    subtitle: '${alerts.length} warnings and package notices',
                    page: const SystemAlertsPage(),
                    locked: false,
                  ),
                  const SizedBox(height: 10),
                  const _InfoNote(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StoreAlertHero extends StatelessWidget {
  const _StoreAlertHero({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.glowShadow('royal_blue'),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(Icons.notifications_active_rounded, color: Colors.white.withOpacity(0.09), size: 118),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Store Alerts', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroPill(label: 'Pending', value: summary['pending_orders'] ?? 0),
                  _HeroPill(label: 'Failed push', value: summary['failed_push_logs'] ?? 0),
                  _HeroPill(label: 'Plan warnings', value: summary['plan_warnings'] ?? 0),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroAction(label: 'Open pending orders', icon: Icons.pending_actions_rounded, page: const OrdersPage(initialStatus: 'pending')),
                  _HeroAction(label: 'Push logs', icon: Icons.mark_email_unread_rounded, page: const PushLogsPage()),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});
  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text('$label: $value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}


class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.label, required this.icon, required this.page});

  final String label;
  final IconData icon;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricItem('Pending', summary['pending_orders'] ?? 0, Icons.pending_actions_outlined, AppTheme.warningGradient, const OrdersPage(initialStatus: 'pending')),
      _MetricItem('Unread Push', summary['unread_push_logs'] ?? 0, Icons.mark_email_unread_outlined, AppTheme.infoGradient, const PushLogsPage()),
      _MetricItem('Failed Push', summary['failed_push_logs'] ?? 0, Icons.error_outline, AppTheme.dangerGradient, const PushLogsPage()),
      _MetricItem('Activity', summary['recent_activity'] ?? 0, Icons.history_outlined, AppTheme.successGradient, const AuditLogsPage()),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 118,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, index) => _MetricCard(item: items[index]),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.title, this.value, this.icon, this.gradient, this.page);
  final String title;
  final Object value;
  final IconData icon;
  final Gradient gradient;
  final Widget page;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});
  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.page)),
        child: Ink(
          padding: const EdgeInsets.all(13),
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
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(gradient: item.gradient, borderRadius: BorderRadius.circular(14)),
                    child: Icon(item.icon, color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, color: AppTheme.muted2, size: 16),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppTheme.muted, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(item.value.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 25, color: AppTheme.text, fontWeight: FontWeight.w900, height: 1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Plan sync: Audit logs follow Advanced Reports package access. Notification center and order badge are core admin features.',
              style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.page, required this.locked, this.requiredPackage = 'Scale'});
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
