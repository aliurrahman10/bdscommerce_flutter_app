import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';
import 'portal_plan_change_page.dart';
import 'portal_service_detail_page.dart';

class PortalServicesPage extends StatefulWidget {
  const PortalServicesPage({super.key});

  @override
  State<PortalServicesPage> createState() => _PortalServicesPageState();
}

class _PortalServicesPageState extends State<PortalServicesPage> {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renewal payment page opened. Complete payment and refresh.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  bool _visibleService(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    final serviceStatus = (item['service_status'] ?? '').toString().toLowerCase();
    return !['deleted', 'cancelled', 'terminated'].contains(status) && !['deleted', 'cancelled', 'terminated'].contains(serviceStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final items = (snapshot.data?['data'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .where(_visibleService)
              .toList();
          if (items.isEmpty) return const Center(child: Text('No active services found.'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, index) => _ServiceCard(
                service: items[index],
                onRenew: () => _renewNow(items[index]),
                onChangePlan: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalPlanChangePage(service: items[index]))),
                onOpenDetails: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalServiceDetailPage(service: items[index]))),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onRenew, required this.onChangePlan, required this.onOpenDetails});
  final Map<String, dynamic> service;
  final VoidCallback onRenew;
  final VoidCallback onChangePlan;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final plan = service['plan'] as Map<String, dynamic>?;
    final name = service['domain']?.toString().trim().isNotEmpty == true
        ? service['domain'].toString()
        : service['tenant_slug']?.toString().trim().isNotEmpty == true
            ? service['tenant_slug'].toString()
            : 'Service #${service['id']}';
    final status = service['service_status']?.toString() ?? service['status']?.toString() ?? 'N/A';
    final currency = service['currency']?.toString() ?? plan?['currency']?.toString() ?? 'BDT';
    final total = service['invoice_total']?.toString() ?? plan?['price']?.toString() ?? '0';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: onOpenDetails,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.underline))),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text('${plan?['name'] ?? 'No plan'} • $status', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text('$currency $total • Due ${service['next_due_date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: onRenew, icon: const Icon(Icons.payments_outlined, size: 18), label: const Text('Renew')),
            OutlinedButton.icon(onPressed: onChangePlan, icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Upgrade')),
            OutlinedButton.icon(onPressed: onOpenDetails, icon: const Icon(Icons.info_outline, size: 18), label: const Text('Details')),
          ]),
        ]),
      ),
    );
  }
}
