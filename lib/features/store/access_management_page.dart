import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'roles_permissions_page.dart';
import 'staff_page.dart';
import '../../shared/widgets/locked_feature.dart';

class AccessManagementPage extends StatefulWidget {
  const AccessManagementPage({super.key});

  @override
  State<AccessManagementPage> createState() => _AccessManagementPageState();
}

class _AccessManagementPageState extends State<AccessManagementPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.accessSummary(workspace.activeStoreToken!);
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
      appBar: AppBar(title: const Text('Access Management'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));

          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final locked = features['staff_accounts'] == false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Staff Access', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Staff: ${summary['staff_count'] ?? 0} / ${summary['staff_limit'] ?? 'unlimited'} • Roles: ${summary['roles'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              const SizedBox(height: 14),
              if (locked)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [Icon(Icons.lock_outline), SizedBox(width: 10), Expanded(child: Text('Staff accounts are locked by the current subscription plan.'))]),
                  ),
                ),
              _AccessTile(icon: Icons.people_alt_outlined, title: 'Staff Accounts', subtitle: 'Add, edit, deactivate and revoke staff sessions', page: const StaffPage(), locked: locked),
              _AccessTile(icon: Icons.verified_user_outlined, title: 'Roles & Permissions', subtitle: 'View available roles and assigned permissions', page: const RolesPermissionsPage(), locked: false),
            ],
          );
        },
      ),
    );
  }
}

class _AccessTile extends StatelessWidget {
  // ignore: unused_element_parameter
  const _AccessTile({required this.icon, required this.title, required this.subtitle, required this.page, required this.locked, this.requiredPackage = 'Scale'});
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
