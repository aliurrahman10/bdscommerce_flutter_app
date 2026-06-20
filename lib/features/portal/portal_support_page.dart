import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';
import 'portal_support_create_page.dart';
import 'portal_support_detail_page.dart';

class PortalSupportPage extends StatefulWidget {
  const PortalSupportPage({super.key, this.service});
  final Map<String, dynamic>? service;

  @override
  State<PortalSupportPage> createState() => _PortalSupportPageState();
}

class _PortalSupportPageState extends State<PortalSupportPage> {
  late Future<Map<String, dynamic>> _future;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.supportTickets(workspace.portalToken!, status: _status);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PortalSupportCreatePage(service: widget.service)));
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Center'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openCreate, icon: const Icon(Icons.add), label: const Text('New Ticket')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = snapshot.data?['data'] as List<dynamic>? ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const Text('Support Tickets', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _StatusChip(label: 'All', value: 'all', selected: _status == 'all', onTap: _changeStatus),
                    _StatusChip(label: 'Open', value: 'open', selected: _status == 'open', onTap: _changeStatus),
                    _StatusChip(label: 'In progress', value: 'in_progress', selected: _status == 'in_progress', onTap: _changeStatus),
                    _StatusChip(label: 'Waiting', value: 'waiting_client', selected: _status == 'waiting_client', onTap: _changeStatus),
                    _StatusChip(label: 'Resolved', value: 'resolved', selected: _status == 'resolved', onTap: _changeStatus),
                  ]),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty) const Card(child: ListTile(title: Text('No support ticket found.'))),
                ...items.map((raw) => _TicketCard(
                      ticket: raw as Map<String, dynamic>,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalSupportDetailPage(ticketId: int.parse(raw['id'].toString()))));
                        _refresh();
                      },
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _changeStatus(String status) {
    setState(() {
      _status = status;
      _future = _load();
    });
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value, required this.selected, required this.onTap});
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(value)),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = ticket['priority']?.toString() ?? 'normal';
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text('#${ticket['id']}')),
        title: Text(ticket['subject']?.toString() ?? 'Support ticket', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${ticket['status'] ?? 'open'} • ${ticket['type'] ?? 'general'} • ${ticket['domain'] ?? ''}'),
        trailing: Chip(label: Text(priority), avatar: Icon(Icons.flag, color: _priorityColor(priority), size: 16)),
      ),
    );
  }
}
