import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';
import 'portal_plan_change_page.dart';

class PortalInvoiceDetailPage extends StatefulWidget {
  const PortalInvoiceDetailPage({super.key, required this.invoiceId});
  final int invoiceId;

  @override
  State<PortalInvoiceDetailPage> createState() => _PortalInvoiceDetailPageState();
}

class _PortalInvoiceDetailPageState extends State<PortalInvoiceDetailPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.billingInvoiceDetail(workspace.portalToken!, widget.invoiceId);
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
      appBar: AppBar(title: Text('Invoice #${widget.invoiceId}'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final invoice = snapshot.data?['invoice'] as Map<String, dynamic>? ?? {};
          final service = invoice['service'] as Map<String, dynamic>? ?? {};
          final payments = snapshot.data?['payments'] as List<dynamic>? ?? [];
          final renewal = snapshot.data?['renewal'] as Map<String, dynamic>?;
          final planRequest = snapshot.data?['plan_request'] as Map<String, dynamic>?;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invoice['invoice_number']?.toString() ?? 'Invoice', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Status: ${invoice['status'] ?? 'unpaid'}'),
              Text('Amount: ৳ ${invoice['total'] ?? 0} ${invoice['currency'] ?? ''}'),
              Text('Due date: ${invoice['due_date'] ?? 'N/A'}'),
              const Divider(height: 24),
              Text(service['domain']?.toString() ?? service['tenant_slug']?.toString() ?? 'Service', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Plan: ${service['plan']?['name'] ?? 'N/A'}'),
              Text('Billing cycle: ${service['billing_cycle'] ?? 'N/A'}'),
            ]))),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.payment), label: const Text('Pay / View'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalPlanChangePage(service: service))), icon: const Icon(Icons.swap_horiz), label: const Text('Change Plan'))),
            ]),
            const SizedBox(height: 12),
            if (renewal != null) Card(child: ListTile(leading: const Icon(Icons.event_repeat_outlined), title: const Text('Renewal'), subtitle: Text('Due: ${renewal['due_date'] ?? 'N/A'} • ${renewal['status'] ?? 'upcoming'}'))),
            if (planRequest != null) Card(child: ListTile(leading: const Icon(Icons.pending_actions_outlined), title: const Text('Latest Package Request'), subtitle: Text('${planRequest['request_type'] ?? ''} • ${planRequest['status'] ?? ''}'))),
            const SizedBox(height: 12),
            const Text('Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            if (payments.isEmpty) const Card(child: ListTile(title: Text('No payment found.'))),
            ...payments.map((raw) {
              final p = raw as Map<String, dynamic>;
              return Card(child: ListTile(title: Text('৳ ${p['amount'] ?? 0} • ${p['status'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${p['gateway'] ?? ''}\n${p['transaction_id'] ?? ''}'), isThreeLine: true));
            }),
          ]);
        },
      ),
    );
  }
}
