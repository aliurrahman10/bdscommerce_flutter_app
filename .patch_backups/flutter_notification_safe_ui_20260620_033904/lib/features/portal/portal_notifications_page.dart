import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';

class PortalNotificationsPage extends StatelessWidget {
  const PortalNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.portalApi.notifications(workspace.portalToken!),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = (snapshot.data?['data'] as List<dynamic>? ?? []);
          if (items.isEmpty) return const Center(child: Text('No notifications found.'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index] as Map<String, dynamic>;
              return Card(
                elevation: 0,
                child: ListTile(
                  title: Text(item['title']?.toString() ?? 'Notification'),
                  subtitle: Text(item['message']?.toString() ?? ''),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
