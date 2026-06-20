import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class RolesPermissionsPage extends StatefulWidget {
  const RolesPermissionsPage({super.key});

  @override
  State<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends State<RolesPermissionsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.accessRoles(workspace.activeStoreToken!);
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
      appBar: AppBar(title: const Text('Roles & Permissions'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final roles = ((snapshot.data?['data'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
          if (roles.isEmpty) return const Center(child: Text('No roles found.'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: roles.length,
            itemBuilder: (context, index) {
              final role = roles[index];
              final permissions = ((role['permissions'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
              final grouped = <String, List<Map<String, dynamic>>>{};
              for (final permission in permissions) {
                grouped.putIfAbsent(permission['group']?.toString() ?? 'General', () => []).add(permission);
              }
              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.verified_user_outlined, color: AppTheme.primary),
                  title: Text(role['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${role['slug'] ?? ''} • ${permissions.length} permissions'),
                  children: [
                    if (permissions.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No permissions assigned.')),
                    ...grouped.entries.map((entry) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: entry.value.map((p) => Chip(label: Text(p['name']?.toString() ?? p['slug']?.toString() ?? ''))).toList(),
                            ),
                          ]),
                        )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
