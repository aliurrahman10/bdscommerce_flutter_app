import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/models/app_mode.dart';
import '../../core/state/workspace_controller.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    if (workspace.activeMode == AppMode.portal) {
      final token = workspace.portalToken!;
      final me = await workspace.portalApi.accountMe(token);
      final sessions = await workspace.portalApi.accountSessions(token);
      return {'me': me, 'sessions': sessions, 'mode': 'portal'};
    }
    final token = workspace.activeStoreToken!;
    final me = await workspace.storeApi.accountMe(token);
    final sessions = await workspace.storeApi.accountSessions(token);
    return {'me': me, 'sessions': sessions, 'mode': 'store'};
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _saveProfile(Map<String, dynamic> user) async {
    final name = TextEditingController(text: user['name']?.toString() ?? '');
    final email = TextEditingController(text: user['email']?.toString() ?? '');
    final phone = TextEditingController(text: user['phone']?.toString() ?? '');
    String theme = user['theme']?.toString() == 'dark' ? 'dark' : 'light';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Update Profile'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: theme,
                decoration: const InputDecoration(labelText: 'App theme preference'),
                items: const [DropdownMenuItem(value: 'light', child: Text('Light')), DropdownMenuItem(value: 'dark', child: Text('Dark'))],
                onChanged: (v) => setLocal(() => theme = v ?? 'light'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final workspace = context.read<WorkspaceController>();
      final data = {'name': name.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim(), 'theme': theme};
      if (workspace.activeMode == AppMode.portal) {
        await workspace.portalApi.updateAccountProfile(workspace.portalToken!, data);
      } else {
        await workspace.storeApi.updateAccountProfile(workspace.activeStoreToken!, data);
      }
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();
    bool revokeOthers = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: current, decoration: const InputDecoration(labelText: 'Current password'), obscureText: true),
              const SizedBox(height: 8),
              TextField(controller: password, decoration: const InputDecoration(labelText: 'New password'), obscureText: true),
              const SizedBox(height: 8),
              TextField(controller: confirm, decoration: const InputDecoration(labelText: 'Confirm new password'), obscureText: true),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: revokeOthers,
                onChanged: (v) => setLocal(() => revokeOthers = v ?? true),
                title: const Text('Logout other devices'),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Change')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final workspace = context.read<WorkspaceController>();
      final data = {
        'current_password': current.text,
        'password': password.text,
        'password_confirmation': confirm.text,
        'revoke_other_sessions': revokeOthers,
      };
      if (workspace.activeMode == AppMode.portal) {
        await workspace.portalApi.changeAccountPassword(workspace.portalToken!, data);
      } else {
        await workspace.storeApi.changeAccountPassword(workspace.activeStoreToken!, data);
      }
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _revokeSession(Map<String, dynamic> session) async {
    try {
      final workspace = context.read<WorkspaceController>();
      final id = int.parse(session['id'].toString());
      if (workspace.activeMode == AppMode.portal) {
        await workspace.portalApi.revokeAccountSession(workspace.portalToken!, id);
      } else {
        await workspace.storeApi.revokeAccountSession(workspace.activeStoreToken!, id);
      }
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session revoked.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _logoutOtherDevices() async {
    try {
      final workspace = context.read<WorkspaceController>();
      if (workspace.activeMode == AppMode.portal) {
        await workspace.portalApi.logoutOtherAccountDevices(workspace.portalToken!);
      } else {
        await workspace.storeApi.logoutOtherAccountDevices(workspace.activeStoreToken!);
      }
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Other devices logged out.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final me = snapshot.data?['me'] as Map<String, dynamic>? ?? {};
          final user = me['user'] as Map<String, dynamic>? ?? {};
          final sessionsPayload = snapshot.data?['sessions'] as Map<String, dynamic>? ?? {};
          final sessions = ((sessionsPayload['data'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                const CircleAvatar(radius: 26, backgroundColor: Colors.white, child: Icon(Icons.person_outline, color: AppTheme.primary)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user['name']?.toString() ?? 'Account', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(user['email']?.toString() ?? '', style: const TextStyle(color: Colors.white70)),
                ])),
              ]),
            ),
            const SizedBox(height: 14),
            Card(child: ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Name, email, phone and theme'), trailing: const Icon(Icons.chevron_right), onTap: () => _saveProfile(user))),
            Card(child: ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Change password and optionally logout other devices'), trailing: const Icon(Icons.chevron_right), onTap: _changePassword)),
            Card(child: ListTile(leading: const Icon(Icons.logout_outlined), title: const Text('Logout Other Devices', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Keep this device logged in'), onTap: _logoutOtherDevices)),
            const SizedBox(height: 12),
            const Text('Active Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (sessions.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No active sessions found.'))),
            ...sessions.map((session) {
              final currentSession = session['is_current'] == true;
              final revoked = session['revoked_at'] != null;
              return Card(
                child: ListTile(
                  leading: Icon(currentSession ? Icons.smartphone : Icons.devices_other_outlined, color: currentSession ? AppTheme.primary : null),
                  title: Text('${session['device_name'] ?? 'Unknown device'}${currentSession ? ' • Current' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Platform: ${session['platform'] ?? 'android'}\nLast used: ${session['last_used_at'] ?? 'Never'}${revoked ? '\nRevoked: ${session['revoked_at']}' : ''}'),
                  isThreeLine: true,
                  trailing: currentSession || revoked ? null : TextButton(onPressed: () => _revokeSession(session), child: const Text('Revoke')),
                ),
              );
            }),
          ]);
        },
      ),
    );
  }
}
