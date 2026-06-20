import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class PushLogsPage extends StatefulWidget {
  const PushLogsPage({super.key});

  @override
  State<PushLogsPage> createState() => _PushLogsPageState();
}

class _PushLogsPageState extends State<PushLogsPage> {
  late Future<Map<String, dynamic>> _future;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.pushLogs(workspace.activeStoreToken!, status: _status);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _markRead(Map<String, dynamic> log, bool read) async {
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.markPushLogRead(workspace.activeStoreToken!, int.parse(log['id'].toString()), read);
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markAllRead() async {
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.markAllPushLogsRead(workspace.activeStoreToken!);
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Push Logs'), actions: [TextButton(onPressed: _markAllRead, child: const Text('Mark read')), IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status filter'),
              items: const [DropdownMenuItem(value: 'all', child: Text('All')), DropdownMenuItem(value: 'sent', child: Text('Sent')), DropdownMenuItem(value: 'failed', child: Text('Failed')), DropdownMenuItem(value: 'skipped', child: Text('Skipped')), DropdownMenuItem(value: 'dry_run', child: Text('Dry run'))],
              onChanged: (v) {
                _status = v ?? 'all';
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                final rows = ((snapshot.data?['data'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
                if (rows.isEmpty) return const Center(child: Text('No push logs found.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final read = row['is_read'] == true;
                    final failed = row['status'] == 'failed';
                    return Card(
                      child: ListTile(
                        leading: Icon(read ? Icons.notifications_none : Icons.notifications_active, color: failed ? Colors.red : AppTheme.primary),
                        title: Text(row['title']?.toString() ?? row['event_type']?.toString() ?? 'Push', style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w900)),
                        subtitle: Text('${row['status'] ?? ''} • ${row['created_at'] ?? ''}${row['error'] != null ? '\n${row['error']}' : ''}'),
                        isThreeLine: row['error'] != null,
                        trailing: TextButton(onPressed: () => _markRead(row, !read), child: Text(read ? 'Unread' : 'Read')),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
