import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';
import 'portal_service_detail_page.dart';

class PortalRenewPage extends StatefulWidget {
  const PortalRenewPage({super.key});

  @override
  State<PortalRenewPage> createState() => _PortalRenewPageState();
}

class _PortalRenewPageState extends State<PortalRenewPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.services(workspace.portalToken!);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  bool _visibleActive(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    final serviceStatus = (item['service_status'] ?? '').toString().toLowerCase();
    if (['deleted', 'cancelled', 'terminated'].contains(status)) return false;
    if (['deleted', 'cancelled', 'terminated'].contains(serviceStatus)) return false;
    return ['active', 'completed', 'paid', 'trial', 'grace', 'suspended', 'overdue'].contains(serviceStatus) || serviceStatus.isEmpty;
  }

  DateTime? _dueDate(Map<String, dynamic> item) {
    final raw = item['next_due_date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _openPayment(String url) async {
    if (url.trim().isEmpty) throw Exception('Payment URL missing.');
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Could not open payment page.');
  }

  Future<void> _renewNow(Map<String, dynamic> service) async {
    final serviceId = int.tryParse(service['id']?.toString() ?? '');
    if (serviceId == null) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.portalToken!;
      final checkout = await workspace.portalApi.startLocalRenewalCheckout(token, serviceId);
      final invoice = checkout['invoice'] as Map<String, dynamic>?;
      final invoiceId = int.tryParse(invoice?['id']?.toString() ?? '');
      if (invoiceId == null) throw Exception('Renewal invoice was not created.');
      final pay = await workspace.portalApi.payLocalBillingInvoice(token, invoiceId);
      await _openPayment(pay['payment_url']?.toString() ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renewal payment page opened. Complete payment and return to app.')));
        _refresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Renew'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = (snapshot.data?['data'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .where(_visibleActive)
              .toList();
          items.sort((a, b) {
            final da = _dueDate(a) ?? DateTime(2999);
            final db = _dueDate(b) ?? DateTime(2999);
            return da.compareTo(db);
          });
          if (items.isEmpty) return const Center(child: Text('No active renewable service found.'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _RenewServiceCard(
                service: items[index],
                onRenew: () => _renewNow(items[index]),
                onDetails: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalServiceDetailPage(service: items[index]))),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RenewServiceCard extends StatelessWidget {
  const _RenewServiceCard({required this.service, required this.onRenew, required this.onDetails});
  final Map<String, dynamic> service;
  final VoidCallback onRenew;
  final VoidCallback onDetails;

  DateTime? _dueDate() {
    final raw = service['next_due_date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  _Urgency _urgency() {
    final due = _dueDate();
    if (due == null) return const _Urgency('No due date', Icons.event_note, Colors.grey);
    final today = DateTime.now();
    final onlyToday = DateTime(today.year, today.month, today.day);
    final onlyDue = DateTime(due.year, due.month, due.day);
    final days = onlyDue.difference(onlyToday).inDays;
    if (days < 0) return _Urgency('Overdue ${days.abs()}d', Icons.warning_amber_rounded, Colors.red);
    if (days == 0) return const _Urgency('Due today', Icons.priority_high_rounded, Colors.deepOrange);
    if (days <= 7) return _Urgency('Urgent: $days days', Icons.timer_outlined, Colors.orange);
    if (days <= 15) return _Urgency('Due soon: $days days', Icons.event_available, Colors.amber);
    return _Urgency('Upcoming: $days days', Icons.event_repeat, Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    final plan = service['plan'] as Map<String, dynamic>?;
    final name = service['domain']?.toString().trim().isNotEmpty == true
        ? service['domain'].toString()
        : service['tenant_slug']?.toString().trim().isNotEmpty == true
            ? service['tenant_slug'].toString()
            : 'Service #${service['id']}';
    final urgency = _urgency();
    final currency = service['currency']?.toString() ?? plan?['currency']?.toString() ?? 'BDT';
    final amount = service['invoice_total']?.toString() ?? plan?['price']?.toString() ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: InkWell(onTap: onDetails, child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)))),
            Chip(avatar: Icon(urgency.icon, color: urgency.color, size: 18), label: Text(urgency.label)),
          ]),
          const SizedBox(height: 8),
          Text('${plan?['name'] ?? 'Package'} • Due ${service['next_due_date'] ?? 'N/A'}'),
          const SizedBox(height: 4),
          Text('$currency $amount • ${service['billing_cycle'] ?? plan?['billing_cycle'] ?? ''}', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: onRenew, icon: const Icon(Icons.payments_outlined), label: const Text('Renew Now'))),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: onDetails, icon: const Icon(Icons.info_outline), label: const Text('Details')),
          ]),
        ]),
      ),
    );
  }
}

class _Urgency {
  const _Urgency(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
