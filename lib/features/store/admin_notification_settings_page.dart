import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';

class AdminNotificationSettingsPage extends StatefulWidget {
  const AdminNotificationSettingsPage({super.key});

  @override
  State<AdminNotificationSettingsPage> createState() => _AdminNotificationSettingsPageState();
}

class _AdminNotificationSettingsPageState extends State<AdminNotificationSettingsPage> {
  late Future<Map<String, dynamic>> _future;
  final _emailsCtrl = TextEditingController();
  final _botTokenCtrl = TextEditingController();
  final _chatIdsCtrl = TextEditingController();
  String _mode = 'none';
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _emailsCtrl.dispose();
    _botTokenCtrl.dispose();
    _chatIdsCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.adminNotificationSettings(workspace.activeStoreToken!);
  }

  void _fill(Map<String, dynamic> settings) {
    if (_loaded) return;
    _mode = settings['admin_order_notification_mode']?.toString() ?? 'none';
    _emailsCtrl.text = settings['admin_emails']?.toString() ?? '';
    _botTokenCtrl.text = settings['admin_order_notification_telegram_bot_token']?.toString() ?? '';
    _chatIdsCtrl.text = settings['admin_order_notification_telegram_chat_ids']?.toString() ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.updateAdminNotificationSettings(workspace.activeStoreToken!, {
        'admin_order_notification_mode': _mode,
        'admin_emails': _emailsCtrl.text.trim(),
        'admin_order_notification_telegram_bot_token': _botTokenCtrl.text.trim(),
        'admin_order_notification_telegram_chat_ids': _chatIdsCtrl.text.trim(),
      });
      _loaded = false;
      final next = _load();
      setState(() => _future = next);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test(String channel) async {
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.testAdminNotification(workspace.activeStoreToken!, channel);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Test completed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Order Notifications')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final settings = snapshot.data?['settings'] as Map<String, dynamic>? ?? {};
          _fill(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('New Order Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _mode,
                      decoration: const InputDecoration(labelText: 'Notification mode'),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'telegram', child: Text('Telegram')),
                        DropdownMenuItem(value: 'both', child: Text('Email + Telegram')),
                      ],
                      onChanged: (v) => setState(() => _mode = v ?? 'none'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _emailsCtrl, decoration: const InputDecoration(labelText: 'Admin emails', hintText: 'admin@example.com, owner@example.com')),
                    const SizedBox(height: 12),
                    TextField(controller: _botTokenCtrl, decoration: const InputDecoration(labelText: 'Telegram bot token', hintText: 'Leave ******** to keep existing')),
                    const SizedBox(height: 12),
                    TextField(controller: _chatIdsCtrl, decoration: const InputDecoration(labelText: 'Telegram chat IDs', hintText: '-1001234567890, 123456789')),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save Settings'))),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Test Notification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _test('email'), icon: const Icon(Icons.email_outlined), label: const Text('Test Email'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => _test('telegram'), icon: const Icon(Icons.send_outlined), label: const Text('Test Telegram')))]),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
