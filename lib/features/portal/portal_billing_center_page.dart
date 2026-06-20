import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';
import 'portal_invoice_detail_page.dart';
import 'portal_plan_change_page.dart';

class PortalBillingCenterPage extends StatefulWidget {
  const PortalBillingCenterPage({super.key});

  @override
  State<PortalBillingCenterPage> createState() => _PortalBillingCenterPageState();
}

class _PortalBillingCenterPageState extends State<PortalBillingCenterPage> {
  late Future<Map<String, dynamic>> _future;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.billingSummary(workspace.portalToken!);
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
      appBar: AppBar(title: const Text('Billing Center'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final alerts = snapshot.data?['alerts'] as List<dynamic>? ?? [];
          final recentRenewals = snapshot.data?['recent_renewals'] as List<dynamic>? ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load();
              setState(() {
                _future = next;
              });
              await next;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Billing Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _MetricGrid(summary: summary),
                const SizedBox(height: 12),
                if (alerts.isNotEmpty) ...[
                  const Text('Billing Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...alerts.map((raw) {
                    final alert = raw as Map<String, dynamic>;
                    return Card(child: ListTile(leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange), title: Text(alert['title']?.toString() ?? 'Alert'), subtitle: Text(alert['message']?.toString() ?? '')));
                  }),
                  const SizedBox(height: 12),
                ],
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PortalPlanChangePage())), icon: const Icon(Icons.swap_horiz), label: const Text('Plan Change'))),
                ]),
                const SizedBox(height: 16),
                const Text('Invoices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _FilterChip(label: 'All', value: 'all', selected: _status == 'all', onTap: _setStatus),
                    _FilterChip(label: 'Unpaid', value: 'unpaid', selected: _status == 'unpaid', onTap: _setStatus),
                    _FilterChip(label: 'Overdue', value: 'overdue', selected: _status == 'overdue', onTap: _setStatus),
                    _FilterChip(label: 'Paid', value: 'paid', selected: _status == 'paid', onTap: _setStatus),
                  ]),
                ),
                const SizedBox(height: 6),
                _InvoiceList(status: _status),
                const SizedBox(height: 18),
                const Text('Renewals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (recentRenewals.isEmpty) const Card(child: ListTile(title: Text('No renewal found.'))),
                ...recentRenewals.map((raw) {
                  final item = raw as Map<String, dynamic>;
                  return Card(child: ListTile(leading: const Icon(Icons.event_repeat_outlined), title: Text(item['service_name']?.toString() ?? item['domain']?.toString() ?? 'Service'), subtitle: Text('Due: ${item['due_date'] ?? 'N/A'} • ${item['status'] ?? 'upcoming'}'), trailing: Text('৳ ${item['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))));
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _setStatus(String value) {
    setState(() => _status = value);
  }
}

class _InvoiceList extends StatefulWidget {
  const _InvoiceList({required this.status});
  final String status;

  @override
  State<_InvoiceList> createState() => _InvoiceListState();
}

class _InvoiceListState extends State<_InvoiceList> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _InvoiceList oldWidget) {
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
    return workspace.portalApi.billingInvoices(workspace.portalToken!, status: widget.status, perPage: 10);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) return Card(child: ListTile(title: Text(snapshot.error.toString())));
        final items = snapshot.data?['data'] as List<dynamic>? ?? [];
        if (items.isEmpty) return const Card(child: ListTile(title: Text('No invoice found.')));
        return Column(children: items.map((raw) {
          final invoice = raw as Map<String, dynamic>;
          final service = invoice['service'] as Map<String, dynamic>? ?? {};
          final status = invoice['status']?.toString() ?? 'unpaid';
          return Card(
            child: ListTile(
              leading: Icon(status == 'paid' ? Icons.check_circle_outline : Icons.receipt_long_outlined, color: status == 'paid' ? Colors.green : Colors.orange),
              title: Text('${invoice['invoice_number'] ?? 'Invoice'} • ৳ ${invoice['total'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${service['domain'] ?? service['tenant_slug'] ?? 'Service'}\nDue: ${invoice['due_date'] ?? 'N/A'} • $status'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalInvoiceDetailPage(invoiceId: int.parse(invoice['id'].toString())))),
            ),
          );
        }).toList());
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) {
    final items = [
      ['Unpaid', summary['unpaid_invoices'] ?? 0],
      ['Overdue', summary['overdue_invoices'] ?? 0],
      ['Due Soon', summary['due_soon_services'] ?? 0],
      ['Total Due', '৳ ${summary['total_due'] ?? 0}'],
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
