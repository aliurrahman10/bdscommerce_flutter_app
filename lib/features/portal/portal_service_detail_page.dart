import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';
import 'portal_plan_change_page.dart';
import 'portal_support_page.dart';

class PortalServiceDetailPage extends StatefulWidget {
  const PortalServiceDetailPage({super.key, required this.service});
  final Map<String, dynamic> service;

  @override
  State<PortalServiceDetailPage> createState() => _PortalServiceDetailPageState();
}

class _PortalServiceDetailPageState extends State<PortalServiceDetailPage> {
  bool _renewing = false;

  int get _serviceId => int.tryParse(widget.service['id']?.toString() ?? '') ?? 0;

  Future<void> _openUrl(String? url) async {
    final value = (url ?? '').trim();
    if (value.isEmpty) return;
    final opened = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Could not open link.');
  }

  Future<void> _renewNow() async {
    if (_serviceId <= 0) return;
    setState(() => _renewing = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.portalToken!;
      final checkout = await workspace.portalApi.startLocalRenewalCheckout(token, _serviceId);
      final invoice = checkout['invoice'] as Map<String, dynamic>?;
      final invoiceId = int.tryParse(invoice?['id']?.toString() ?? '');
      if (invoiceId == null) throw Exception('Renewal invoice was not created.');
      final pay = await workspace.portalApi.payLocalBillingInvoice(token, invoiceId);
      await _openUrl(pay['payment_url']?.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renewal payment page opened. Complete payment and refresh.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final plan = service['plan'] as Map<String, dynamic>?;
    final name = service['domain']?.toString().trim().isNotEmpty == true
        ? service['domain'].toString()
        : service['tenant_slug']?.toString().trim().isNotEmpty == true
            ? service['tenant_slug'].toString()
            : 'Service #${service['id']}';
    final status = service['service_status']?.toString() ?? service['status']?.toString() ?? 'N/A';
    final currency = service['currency']?.toString() ?? plan?['currency']?.toString() ?? 'BDT';
    final total = service['invoice_total']?.toString() ?? plan?['price']?.toString() ?? '0';

    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text(status)),
                  if (service['invoice_status'] != null) Chip(label: Text('Invoice: ${service['invoice_status']}')),
                  if (service['entitlement_status'] != null) Chip(label: Text('Sync: ${service['entitlement_status']}')),
                ]),
              ]),
            ),
          ),
          Card(
            child: Column(children: [
              _InfoTile(label: 'Current package', value: plan?['name']?.toString() ?? 'N/A'),
              _InfoTile(label: 'Recurring amount', value: '$currency $total'),
              _InfoTile(label: 'Billing cycle', value: service['billing_cycle']?.toString() ?? plan?['billing_cycle']?.toString() ?? 'N/A'),
              _InfoTile(label: 'Next due date', value: service['next_due_date']?.toString() ?? 'N/A'),
              _InfoTile(label: 'Invoice number', value: service['invoice_number']?.toString() ?? 'N/A'),
            ]),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _renewing ? null : _renewNow,
                  icon: _renewing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payments_outlined),
                  label: Text(_renewing ? 'Opening payment...' : 'Renew Now'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalPlanChangePage(service: service))),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Upgrade / Downgrade'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PortalSupportPage(service: service))),
                  icon: const Icon(Icons.support_agent_outlined),
                  label: const Text('Support Ticket'),
                ),
                if ((service['store_url'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: () => _openUrl(service['store_url']?.toString()), icon: const Icon(Icons.public), label: const Text('Open Store')),
                ],
                if ((service['admin_url'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: () => _openUrl(service['admin_url']?.toString()), icon: const Icon(Icons.admin_panel_settings_outlined), label: const Text('Open Store Admin')),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label, style: TextStyle(color: Colors.grey.shade600)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}
