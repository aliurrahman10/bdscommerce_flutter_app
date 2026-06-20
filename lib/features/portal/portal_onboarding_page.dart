import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';
import 'portal_onboarding_detail_page.dart';

class PortalOnboardingPage extends StatefulWidget {
  const PortalOnboardingPage({super.key});
  @override
  State<PortalOnboardingPage> createState() => _PortalOnboardingPageState();
}

class _PortalOnboardingPageState extends State<PortalOnboardingPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() => context.read<WorkspaceController>().portalApi.onboardingList(context.read<WorkspaceController>().portalToken!);
  Future<void> _refresh() async { final next = _load(); setState(() { _future = next; }); await next; }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding Center')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          if (items.isEmpty) return const Center(child: Text('No onboarding item found.'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(padding: const EdgeInsets.all(12), children: [
              const Padding(padding: EdgeInsets.all(8), child: Text('Complete business information, upload logo/screenshots and submit setup details for review.')),
              for (final item in items) Card(child: ListTile(
                leading: CircleAvatar(child: Text('${item['completion_percent'] ?? 0}%')),
                title: Text(item['service_name']?.toString() ?? 'Service onboarding', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item['domain'] ?? '-'}\nStatus: ${item['status'] ?? 'pending'}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalOnboardingDetailPage(id: int.parse(item['id'].toString())))); _refresh(); },
              )),
            ]),
          );
        },
      ),
    );
  }
}
