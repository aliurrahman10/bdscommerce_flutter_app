import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    final staff = await workspace.storeApi.staff(token);
    final roles = await workspace.storeApi.accessRoles(token);
    return {'staff': staff, 'roles': roles};
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  List<Map<String, dynamic>> _roleRows(Map<String, dynamic>? data) {
    final roleData = data?['roles'] as Map<String, dynamic>?;
    return ((roleData?['data'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _staffRows(Map<String, dynamic>? data) {
    final staffData = data?['staff'] as Map<String, dynamic>?;
    return ((staffData?['data'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _staffDialog(List<Map<String, dynamic>> roles, [Map<String, dynamic>? staff]) async {
    final name = TextEditingController(text: staff?['name']?.toString() ?? '');
    final email = TextEditingController(text: staff?['email']?.toString() ?? '');
    final password = TextEditingController();
    final memberRole = TextEditingController(text: staff?['member_role']?.toString() ?? 'staff');
    String status = staff?['status']?.toString() ?? 'active';
    String theme = staff?['theme']?.toString() ?? 'light';
    final selectedRoles = <int>{};
    for (final r in ((staff?['roles'] ?? []) as List<dynamic>)) {
      final id = int.tryParse((r as Map<String, dynamic>)['id'].toString());
      if (id != null) selectedRoles.add(id);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(staff == null ? 'Add Staff' : 'Edit Staff'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: password, decoration: InputDecoration(labelText: staff == null ? 'Password' : 'New password (optional)'), obscureText: true),
              const SizedBox(height: 8),
              TextField(controller: memberRole, decoration: const InputDecoration(labelText: 'Member role label')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [DropdownMenuItem(value: 'active', child: Text('Active')), DropdownMenuItem(value: 'inactive', child: Text('Inactive'))],
                onChanged: (v) => setLocal(() => status = v ?? 'active'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: theme,
                decoration: const InputDecoration(labelText: 'Theme'),
                items: const [DropdownMenuItem(value: 'light', child: Text('Light')), DropdownMenuItem(value: 'dark', child: Text('Dark'))],
                onChanged: (v) => setLocal(() => theme = v ?? 'light'),
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Roles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              if (roles.isEmpty) const Text('No roles found.'),
              ...roles.map((role) {
                final roleId = int.parse(role['id'].toString());
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selectedRoles.contains(roleId),
                  title: Text(role['name']?.toString() ?? ''),
                  subtitle: Text(role['slug']?.toString() ?? ''),
                  onChanged: (v) {
                    setLocal(() {
                      if (v == true) {
                        selectedRoles.add(roleId);
                      } else {
                        selectedRoles.remove(roleId);
                      }
                    });
                  },
                );
              }),
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
      final token = workspace.activeStoreToken!;
      final data = <String, dynamic>{
        'name': name.text.trim(),
        'email': email.text.trim(),
        'member_role': memberRole.text.trim().isEmpty ? 'staff' : memberRole.text.trim(),
        'status': status,
        'theme': theme,
        'role_ids': selectedRoles.toList(),
        if (password.text.trim().isNotEmpty) 'password': password.text.trim(),
      };
      if (staff == null) {
        await workspace.storeApi.createStaff(token, data);
      } else {
        await workspace.storeApi.updateStaff(token, int.parse(staff['id'].toString()), data);
      }
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteStaff(Map<String, dynamic> staff) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove staff?'),
        content: Text('Remove ${staff['name']} from this store?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))],
      ),
    );
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.deleteStaff(workspace.activeStoreToken!, int.parse(staff['id'].toString()));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _revokeSessions(Map<String, dynamic> staff) async {
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.revokeStaffSessions(workspace.activeStoreToken!, int.parse(staff['id'].toString()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff sessions revoked.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final roles = _roleRows(snapshot.data);
        return Scaffold(
          appBar: AppBar(title: const Text('Staff Accounts'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _staffDialog(roles), icon: const Icon(Icons.add), label: const Text('Staff')),
          body: Builder(builder: (context) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final rows = _staffRows(snapshot.data);
            if (rows.isEmpty) return const Center(child: Text('No staff found.'));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final rolesText = ((row['roles'] ?? []) as List<dynamic>).map((e) => (e as Map<String, dynamic>)['name'].toString()).join(', ');
                final owner = row['is_owner'] == true;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(.12), child: Icon(owner ? Icons.verified_user_outlined : Icons.person_outline, color: AppTheme.primary)),
                    title: Text('${row['name']}${owner ? ' • Owner' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${row['email']}\n${row['status']} • ${row['member_role'] ?? ''}${rolesText.isNotEmpty ? '\nRoles: $rolesText' : ''}'),
                    isThreeLine: true,
                    trailing: owner
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _staffDialog(roles, row);
                              if (v == 'revoke') _revokeSessions(row);
                              if (v == 'delete') _deleteStaff(row);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'revoke', child: Text('Revoke sessions')),
                              PopupMenuItem(value: 'delete', child: Text('Remove')),
                            ],
                          ),
                    onTap: owner ? null : () => _staffDialog(roles, row),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}
