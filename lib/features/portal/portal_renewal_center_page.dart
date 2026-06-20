import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';

class PortalRenewalCenterPage extends StatefulWidget {
  const PortalRenewalCenterPage({super.key});

  @override
  State<PortalRenewalCenterPage> createState() => _PortalRenewalCenterPageState();
}

class _PortalRenewalCenterPageState extends State<PortalRenewalCenterPage> {
  late Future<Map<String, dynamic>> _future;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.renewalSummary(workspace.portalToken!);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _openPaymentUrl(String url) async {
    if (url.trim().isEmpty) throw Exception('Payment URL missing.');
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Could not open payment page.');
  }

  Future<void> _renewNow(Map<String, dynamic> renewal) async {
    final orderId = int.tryParse((renewal['portal_order_id'] ?? '').toString());
    if (orderId == null || orderId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This renewal is not linked with a service order.')));
      return;
    }
    try {
      final workspace = context.read<WorkspaceController>();
      final checkout = await workspace.portalApi.startLocalRenewalCheckout(workspace.portalToken!, orderId);
      final invoice = checkout['invoice'] as Map<String, dynamic>? ?? {};
      final invoiceId = int.tryParse((invoice['id'] ?? '').toString());
      if (invoiceId == null) throw Exception('Renewal invoice was not created.');
      final pay = await workspace.portalApi.payLocalBillingInvoice(workspace.portalToken!, invoiceId);
      final paymentUrl = pay['payment_url']?.toString() ?? '';
      await _openPaymentUrl(paymentUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment page opened. Complete payment and return to app, then refresh.')));
        _refresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _createSnapshot() async {
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.portalApi.createRenewalSnapshotNotifications(workspace.portalToken!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Snapshot created.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markAllRead() async {
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.portalApi.markAllRenewalRemindersRead(workspace.portalToken!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Marked as read.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _requestSupport(Map<String, dynamic> renewal) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request renewal support'),
        content: TextField(controller: noteCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Message / note')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.portalApi.requestRenewal(workspace.portalToken!, {
        'portal_order_id': renewal['portal_order_id'],
        'message': noteCtrl.text.trim(),
        'priority': renewal['status'] == 'overdue' ? 'high' : 'normal',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Renewal request submitted.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Renewal Center'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final alerts = snapshot.data?['alerts'] as List<dynamic>? ?? [];
          final notifications = snapshot.data?['recent_notifications'] as List<dynamic>? ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load();
              setState(() {
                _future = next;
              });
              await next;
            },
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Renewal Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _MetricGrid(summary: summary),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _createSnapshot, icon: const Icon(Icons.notifications_active_outlined), label: const Text('Create Alerts'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _markAllRead, icon: const Icon(Icons.done_all), label: const Text('Mark Read'))),
              ]),
              const SizedBox(height: 16),
              if (alerts.isNotEmpty) ...[
                const Text('Need attention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...alerts.map((raw) {
                  final item = raw as Map<String, dynamic>;
                  return _RenewalCard(item: item, onRenew: () => _renewNow(item), onSupport: () => _requestSupport(item));
                }),
                const SizedBox(height: 16),
              ],
              const Text('All Renewals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _FilterChip(label: 'All', value: 'all', selected: _status == 'all', onTap: (v) => setState(() => _status = v)),
                _FilterChip(label: 'Due Soon', value: 'due_soon', selected: _status == 'due_soon', onTap: (v) => setState(() => _status = v)),
                _FilterChip(label: 'Overdue', value: 'overdue', selected: _status == 'overdue', onTap: (v) => setState(() => _status = v)),
                _FilterChip(label: 'Upcoming', value: 'upcoming', selected: _status == 'upcoming', onTap: (v) => setState(() => _status = v)),
              ])),
              const SizedBox(height: 8),
              _RenewalList(status: _status, onRenew: _renewNow, onSupport: _requestSupport),
              const SizedBox(height: 18),
              const Text('Reminder Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (notifications.isEmpty) const Card(child: ListTile(title: Text('No renewal notification yet.'))),
              ...notifications.map((raw) {
                final n = raw as Map<String, dynamic>;
                return Card(child: ListTile(leading: Icon(n['read_at'] == null ? Icons.notifications_active : Icons.notifications_none), title: Text(n['title']?.toString() ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(n['message']?.toString() ?? '')));
              }),
            ]),
          );
        },
      ),
    );
  }
}

class _RenewalList extends StatefulWidget {
  const _RenewalList({required this.status, required this.onRenew, required this.onSupport});
  final String status;
  final Future<void> Function(Map<String, dynamic> renewal) onRenew;
  final Future<void> Function(Map<String, dynamic> renewal) onSupport;

  @override
  State<_RenewalList> createState() => _RenewalListState();
}

class _RenewalListState extends State<_RenewalList> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _RenewalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      final next = _load();
      setState(() {
        _future = next;
      });
    }
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.renewalList(workspace.portalToken!, status: widget.status);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) return Card(child: ListTile(title: Text(snapshot.error.toString())));
        final items = snapshot.data?['data'] as List<dynamic>? ?? [];
        if (items.isEmpty) return const Card(child: ListTile(title: Text('No renewal found.')));
        return Column(children: items.map((raw) {
          final item = raw as Map<String, dynamic>;
          return _RenewalCard(item: item, onRenew: () => widget.onRenew(item), onSupport: () => widget.onSupport(item));
        }).toList());
      },
    );
  }
}

class _RenewalCard extends StatelessWidget {
  const _RenewalCard({required this.item, required this.onRenew, required this.onSupport});
  final Map<String, dynamic> item;
  final VoidCallback onRenew;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'upcoming';
    final dangerous = status == 'overdue';
    final renewed = status == 'renewed';
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(dangerous ? Icons.warning_amber_outlined : Icons.event_repeat_outlined, color: dangerous ? Colors.red : Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(item['service_name']?.toString() ?? item['domain']?.toString() ?? 'Service', style: const TextStyle(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 8),
        Text('Due: ${item['due_date'] ?? 'N/A'} • $status\n${item['plan_name'] ?? ''} • ৳ ${item['amount'] ?? 0}'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: renewed ? null : onRenew, icon: const Icon(Icons.payment), label: const Text('Renew Now'))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onSupport, child: const Text('Support')),
        ]),
      ]),
    ));
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) {
    final items = [
      ['Due Soon', summary['due_soon'] ?? 0],
      ['Overdue', summary['overdue'] ?? 0],
      ['Upcoming', summary['upcoming'] ?? 0],
      ['Unread', summary['unread_renewal_notifications'] ?? 0],
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.85, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemBuilder: (_, index) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(items[index][0].toString(), style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 6), Text(items[index][1].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))]))),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(value)));
}
