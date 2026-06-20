import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/models/app_mode.dart';
import '../../core/services/push_token_service.dart';
import '../../core/state/workspace_controller.dart';

class MobileQualityPage extends StatefulWidget {
  const MobileQualityPage({super.key});

  @override
  State<MobileQualityPage> createState() => _MobileQualityPageState();
}

class _MobileQualityPageState extends State<MobileQualityPage> {
  late Future<Map<String, dynamic>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    await _syncCurrentDeviceToken(workspace);
    if (workspace.activeMode == AppMode.store) {
      return workspace.storeApi.storePushStatus(workspace.activeStoreToken!);
    }
    return workspace.portalApi.portalPushStatus(workspace.portalToken!);
  }

  Future<void> _syncCurrentDeviceToken(WorkspaceController workspace) async {
    final deviceToken = await PushTokenService.instance.getToken();
    if (deviceToken == null || deviceToken.isEmpty) return;

    try {
      if (workspace.activeMode == AppMode.store && workspace.activeStoreToken != null) {
        await workspace.storeApi.saveDeviceToken(workspace.activeStoreToken!, deviceToken);
      } else if (workspace.activeMode == AppMode.portal && workspace.portalToken != null) {
        await workspace.portalApi.saveDeviceToken(workspace.portalToken!, deviceToken);
      }
    } catch (_) {
      // Keep status page usable even if token syncing fails.
    }
  }

  void _refresh() {
    final nextFuture = _load();
    setState(() {
      _future = nextFuture;
    });
  }

  Future<void> _sendTestPush() async {
    setState(() => _sending = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final response = workspace.activeMode == AppMode.store
          ? await workspace.storeApi.sendStoreTestPush(workspace.activeStoreToken!)
          : await workspace.portalApi.sendPortalTestPush(workspace.portalToken!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message']?.toString() ?? 'Test completed.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final title = workspace.activeMode == AppMode.store ? 'Store Push & Plan Audit' : 'Portal Push Status';
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sending ? null : _sendTestPush,
        icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.notifications_active_outlined),
        label: Text(_sending ? 'Sending...' : 'Send Test Push'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final data = snapshot.data ?? {};
          final fcm = data['fcm'] as Map<String, dynamic>? ?? {};
          final tokens = data['device_tokens'] as Map<String, dynamic>? ?? {};
          final logs = data['push_logs'] as Map<String, dynamic>? ?? {};
          final recent = (data['recent_logs'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final audit = data['plan_audit'] as Map<String, dynamic>?;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              _StatusCard(title: 'Firebase Status', items: [
                _kv('Enabled', fcm['enabled'] == true ? 'Yes' : 'No'),
                _kv('Project ID', fcm['project_id_set'] == true ? 'Set' : 'Missing'),
                _kv('Service Account', fcm['service_account_path_exists'] == true || fcm['service_account_json_set'] == true ? 'Ready' : 'Missing'),
                if (fcm['cron_command'] != null) _kv('Portal Cron', fcm['cron_command'].toString()),
              ]),
              _StatusCard(title: 'Device Tokens', items: tokens.entries.map((e) => _kv(e.key.replaceAll('_', ' '), e.value.toString())).toList()),
              _StatusCard(title: 'Push Logs', items: logs.entries.map((e) => _kv(e.key, e.value.toString())).toList()),
              if (audit != null) _PlanAuditCard(audit: audit),
              const SizedBox(height: 14),
              const Text('Recent Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (recent.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No push log yet.'))),
              for (final log in recent) Card(child: ListTile(
                leading: Icon(log['status'] == 'sent' ? Icons.check_circle : Icons.info_outline, color: log['status'] == 'sent' ? AppTheme.primary : Colors.orange),
                title: Text(log['title']?.toString() ?? log['event_type']?.toString() ?? 'Push log', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${log['event_type'] ?? ''}\n${log['error'] ?? log['created_at'] ?? ''}'),
                isThreeLine: true,
                trailing: Text(log['status']?.toString() ?? ''),
              )),
            ],
          );
        },
      ),
    );
  }

  MapEntry<String, String> _kv(String key, String value) => MapEntry(key, value);
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.items});
  final String title;
  final List<MapEntry<String, String>> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          for (final item in items) Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [Expanded(child: Text(item.key, style: const TextStyle(color: AppTheme.muted))), Text(item.value, style: const TextStyle(fontWeight: FontWeight.w900))]),
          ),
        ]),
      ),
    );
  }
}

class _PlanAuditCard extends StatelessWidget {
  const _PlanAuditCard({required this.audit});
  final Map<String, dynamic> audit;

  @override
  Widget build(BuildContext context) {
    final features = (audit['checked_features'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final allowedGateways = audit['allowed_gateways'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Plan Sync Audit', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(audit['note']?.toString() ?? '', style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 10),
          Text('Allowed gateways: ${allowedGateways is List ? allowedGateways.join(', ') : 'All available'}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final f in features) ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(f['enabled'] == true ? Icons.check_circle : Icons.lock_outline, color: f['enabled'] == true ? AppTheme.primary : Colors.grey),
            title: Text(f['feature']?.toString() ?? ''),
            trailing: Text(f['state']?.toString() ?? ''),
          ),
        ]),
      ),
    );
  }
}
