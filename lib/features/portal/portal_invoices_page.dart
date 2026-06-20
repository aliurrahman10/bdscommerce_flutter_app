import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';

class PortalInvoicesPage extends StatefulWidget {
  const PortalInvoicesPage({super.key});

  @override
  State<PortalInvoicesPage> createState() => _PortalInvoicesPageState();
}

class _PortalInvoicesPageState extends State<PortalInvoicesPage> {
  late Future<Map<String, dynamic>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.localBillingInvoices(workspace.portalToken!, perPage: 100);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  bool _isPaid(Map<String, dynamic> invoice) {
    final status = (invoice['status'] ?? '').toString().toLowerCase();
    return ['paid', 'verified', 'admin_approved'].contains(status) || invoice['paid_at'] != null;
  }

  Future<void> _pay(Map<String, dynamic> invoice) async {
    final invoiceId = int.tryParse(invoice['id']?.toString() ?? '');
    if (invoiceId == null) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.portalApi.payLocalBillingInvoice(workspace.portalToken!, invoiceId);
      final url = res['payment_url']?.toString() ?? '';
      if (url.trim().isEmpty) throw Exception('Payment URL missing.');
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open payment page.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment page opened. Complete payment and refresh.')));
        _refresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    if (_filter == 'paid') return items.where(_isPaid).toList();
    if (_filter == 'unpaid') return items.where((e) => !_isPaid(e)).toList();
    if (_filter == 'renewal') return items.where((e) => (e['invoice_type'] ?? '').toString() == 'renewal').toList();
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final rawItems = snapshot.data?['data'] as List<dynamic>? ?? [];
          final items = _filterItems(rawItems.whereType<Map<String, dynamic>>().toList());
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Invoices', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _Filter(label: 'All', value: 'all', selected: _filter == 'all', onTap: _setFilter),
                    _Filter(label: 'Unpaid', value: 'unpaid', selected: _filter == 'unpaid', onTap: _setFilter),
                    _Filter(label: 'Paid', value: 'paid', selected: _filter == 'paid', onTap: _setFilter),
                    _Filter(label: 'Renewal', value: 'renewal', selected: _filter == 'renewal', onTap: _setFilter),
                  ]),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty) const Card(child: ListTile(title: Text('No invoice found.'))),
                ...items.map((invoice) => _InvoiceCard(invoice: invoice, paid: _isPaid(invoice), onPay: () => _pay(invoice))),
              ],
            ),
          );
        },
      ),
    );
  }

  void _setFilter(String value) {
    setState(() => _filter = value);
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.value, required this.selected, required this.onTap});
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

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.paid, required this.onPay});
  final Map<String, dynamic> invoice;
  final bool paid;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final status = invoice['status']?.toString() ?? 'unpaid';
    final color = paid ? Colors.green : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(invoice['invoice_number']?.toString() ?? 'Invoice', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            Chip(label: Text(status), avatar: Icon(paid ? Icons.check_circle : Icons.error_outline, color: color, size: 18)),
          ]),
          const SizedBox(height: 6),
          Text(invoice['title']?.toString() ?? invoice['invoice_type']?.toString() ?? 'Local invoice'),
          const SizedBox(height: 4),
          Text('${invoice['service_name'] ?? ''} • ${invoice['plan_name'] ?? ''}', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('${invoice['currency'] ?? 'BDT'} ${invoice['amount'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Due: ${invoice['due_date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600)),
          if (!paid) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onPay, icon: const Icon(Icons.payment), label: const Text('Pay Now'))),
          ],
        ]),
      ),
    );
  }
}
