import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'audit_logs_page.dart';
import 'orders_page.dart';
import 'push_logs_page.dart';
import 'system_alerts_page.dart';
import '../../shared/widgets/locked_feature.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Center'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          final alerts = ((snapshot.data?['alerts'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
          final auditLocked = features['audit_logs'] == false;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Store Alerts', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Pending orders: ${summary['pending_orders'] ?? 0} • Failed push: ${summary['failed_push_logs'] ?? 0} • Plan warnings: ${summary['plan_warnings'] ?? 0}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 14),
            _MetricGrid(summary: summary),
            const SizedBox(height: 14),
            _Tile(icon: Icons.shopping_bag_outlined, title: 'Pending Orders', subtitle: '${summary['pending_orders'] ?? 0} pending orders need attention', page: const OrdersPage(), locked: false),
            _Tile(icon: Icons.notifications_active_outlined, title: 'Push Notification Logs', subtitle: 'Sent, failed and unread push history', page: const PushLogsPage(), locked: false),
            _Tile(icon: Icons.history_outlined, title: 'Activity / Audit Logs', subtitle: 'Who changed what across store modules', page: const AuditLogsPage(), locked: auditLocked),
            _Tile(icon: Icons.warning_amber_outlined, title: 'System & Plan Alerts', subtitle: '${alerts.length} warnings and package notices', page: const SystemAlertsPage(), locked: false),
            const SizedBox(height: 10),
            const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Plan sync: Audit logs follow Advanced Reports package access. Notification center and order badge are core admin features.'))),
          ]);
        },
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
      ['Pending', summary['pending_orders'] ?? 0, Icons.pending_actions_outlined],
      ['Unread Push', summary['unread_push_logs'] ?? 0, Icons.mark_email_unread_outlined],
      ['Failed Push', summary['failed_push_logs'] ?? 0, Icons.error_outline],
      ['Activity', summary['recent_activity'] ?? 0, Icons.history_outlined],
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemBuilder: (_, index) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(items[index][2] as IconData, color: AppTheme.primary), const SizedBox(height: 6), Text(items[index][0].toString()), Text(items[index][1].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))]))),
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
