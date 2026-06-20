import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';

class PortalLocalBillingPage extends StatefulWidget {
  const PortalLocalBillingPage({super.key});

  @override
  State<PortalLocalBillingPage> createState() => _PortalLocalBillingPageState();
}

class _PortalLocalBillingPageState extends State<PortalLocalBillingPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.localBillingInvoices(workspace.portalToken!);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _pay(Map<String, dynamic> invoice) async {
    final invoiceId = int.tryParse((invoice['id'] ?? '').toString());
    if (invoiceId == null) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.portalApi.payLocalBillingInvoice(workspace.portalToken!, invoiceId);
      final url = res['payment_url']?.toString() ?? '';
      if (url.trim().isEmpty) throw Exception('Payment URL missing.');
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open payment page.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment page opened. Complete payment and return to app, then refresh.')));
        _refresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Billing'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = snapshot.data?['data'] as List<dynamic>? ?? [];
          if (items.isEmpty) return const Center(child: Text('No local invoice found.'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                final paid = item['status']?.toString() == 'paid' || item['paid_at'] != null;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(item['invoice_number']?.toString() ?? 'Invoice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                        Chip(label: Text(item['status']?.toString() ?? 'unpaid')),
                      ]),
                      const SizedBox(height: 6),
                      Text('${item['title'] ?? ''}\n${item['service_name'] ?? ''} • ${item['plan_name'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text('${item['currency'] ?? 'BDT'} ${item['amount'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (!paid) FilledButton.icon(onPressed: () => _pay(item), icon: const Icon(Icons.payment), label: const Text('Pay Now')),
                    ]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
