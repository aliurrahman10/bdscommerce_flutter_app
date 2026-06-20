import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';

class PortalPlanChangePage extends StatefulWidget {
  const PortalPlanChangePage({super.key, this.service});
  final Map<String, dynamic>? service;

  @override
  State<PortalPlanChangePage> createState() => _PortalPlanChangePageState();
}

class _PortalPlanChangePageState extends State<PortalPlanChangePage> {
  late Future<Map<String, dynamic>> _future;
  final _note = TextEditingController();
  int? _serviceId;
  int? _planId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _serviceId = int.tryParse(widget.service?['id']?.toString() ?? '');
    _future = _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.portalToken!;
    final results = await Future.wait([
      workspace.portalApi.services(token),
      workspace.portalApi.billingPlans(token),
      workspace.portalApi.billingPlanRequests(token),
    ]);
    return {'services': results[0], 'plans': results[1], 'requests': results[2]};
  }

  Map<String, dynamic>? _selectedService(List<dynamic> services) {
    for (final item in services) {
      if (item is Map<String, dynamic> && int.tryParse(item['id'].toString()) == _serviceId) {
        return item;
      }
    }
    return null;
  }

  Map<String, dynamic>? _selectedPlan(List<dynamic> plans) {
    for (final item in plans) {
      if (item is Map<String, dynamic> && int.tryParse(item['id'].toString()) == _planId) {
        return item;
      }
    }
    return null;
  }

  int? _currentPlanId(List<dynamic> services) {
    final raw = _selectedService(services);
    final plan = raw?['plan'];
    if (plan is Map<String, dynamic>) return int.tryParse(plan['id']?.toString() ?? '');
    return null;
  }

  double _selectedServicePrice(List<dynamic> services) {
    final raw = _selectedService(services);
    final plan = raw?['plan'];
    if (plan is Map<String, dynamic>) {
      return double.tryParse((plan['price'] ?? raw?['recurring_amount'] ?? 0).toString()) ?? 0;
    }
    return double.tryParse((raw?['recurring_amount'] ?? 0).toString()) ?? 0;
  }

  double _selectedPlanPrice(List<dynamic> plans) {
    final raw = _selectedPlan(plans);
    return double.tryParse((raw?['price'] ?? 0).toString()) ?? 0;
  }

  String _detectType(List<dynamic> services, List<dynamic> plans) {
    final current = _selectedServicePrice(services);
    final target = _selectedPlanPrice(plans);
    if (_planId == null) return 'change';
    if (target > current) return 'upgrade';
    if (target < current) return 'downgrade';
    return 'change';
  }

  Future<void> _openPayment(String url) async {
    if (url.trim().isEmpty) throw Exception('Payment URL missing.');
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Could not open payment page.');
  }

  Future<void> _submit(List<dynamic> services, List<dynamic> plans) async {
    if (_serviceId == null || _planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select service and target plan.')));
      return;
    }
    final activePlanId = _currentPlanId(services);
    if (activePlanId != null && activePlanId == _planId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This package is already active. Please choose a different package.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final detectedType = _detectType(services, plans);
      final res = await workspace.portalApi.createBillingPlanRequest(workspace.portalToken!, {
        'portal_order_id': _serviceId,
        'requested_plan_id': _planId,
        'request_type': detectedType,
        'urgency': 'normal',
        'message': _note.text.trim(),
      });
      final invoice = res['invoice'] as Map<String, dynamic>?;
      if (invoice != null && invoice['id'] != null) {
        final invoiceId = int.parse(invoice['id'].toString());
        final pay = await workspace.portalApi.payLocalBillingInvoice(workspace.portalToken!, invoiceId);
        await _openPayment(pay['payment_url']?.toString() ?? '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade invoice created. Complete payment and return to app.')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Request submitted.')));
        }
      }
      final next = _load();
      if (mounted) {
        setState(() {
          _future = next;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Package')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final services = snapshot.data?['services']?['data'] as List<dynamic>? ?? [];
          final plans = snapshot.data?['plans']?['data'] as List<dynamic>? ?? [];
          final requests = snapshot.data?['requests']?['data'] as List<dynamic>? ?? [];
          final currentPlanId = _currentPlanId(services);
          final current = _selectedServicePrice(services);
          final target = _selectedPlanPrice(plans);
          final delta = target - current;
          final selectedPlan = _selectedPlan(plans);
          final currency = selectedPlan?['currency']?.toString() ?? 'BDT';
          final preview = _planId == null
              ? 'Select a target plan.'
              : currentPlanId == _planId
                  ? 'This package is already active. Please choose a different package.'
                  : delta > 0
                      ? 'Upgrade invoice will be created now. Amount due: $currency ${delta.toStringAsFixed(2)}. Package activates after payment.'
                      : delta < 0
                          ? 'Downgrade request will be sent for admin approval and scheduled for next billing cycle.'
                          : 'Same-price package change will be submitted for review.';

          final planItems = plans.map((raw) {
            final p = raw as Map<String, dynamic>;
            final id = int.parse(p['id'].toString());
            final activeSuffix = id == currentPlanId ? ' (current)' : '';
            return DropdownMenuItem<int>(
              value: id,
              child: Text('${p['name']}$activeSuffix • ${p['currency'] ?? 'BDT'} ${p['price'] ?? 0}'),
            );
          }).toList();

          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Change package', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: services.any((e) => int.tryParse((e as Map)['id'].toString()) == _serviceId) ? _serviceId : null,
                decoration: const InputDecoration(labelText: 'Service'),
                items: services.map((raw) {
                  final s = raw as Map<String, dynamic>;
                  final id = int.parse(s['id'].toString());
                  final plan = s['plan'] as Map<String, dynamic>?;
                  return DropdownMenuItem<int>(value: id, child: Text('${s['domain'] ?? s['tenant_slug'] ?? 'Service'} • ${plan?['name'] ?? 'Plan'}'));
                }).toList(),
                onChanged: (value) => setState(() {
                  _serviceId = value;
                  if (_currentPlanId(services) == _planId) _planId = null;
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: plans.any((e) => int.tryParse((e as Map)['id'].toString()) == _planId) ? _planId : null,
                decoration: const InputDecoration(labelText: 'Target package'),
                items: planItems,
                onChanged: (value) => setState(() => _planId = value),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35)),
                child: Text(preview),
              ),
              const SizedBox(height: 10),
              TextField(controller: _note, maxLines: 4, decoration: const InputDecoration(labelText: 'Note / reason')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : () => _submit(services, plans),
                  icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.swap_horiz),
                  label: Text(_submitting ? 'Processing...' : 'Continue'),
                ),
              ),
            ]))),
            const SizedBox(height: 16),
            const Text('Previous Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            if (requests.isEmpty) const Card(child: ListTile(title: Text('No package change request yet.'))),
            ...requests.map((raw) {
              final r = raw as Map<String, dynamic>;
              final plan = r['requested_plan'] as Map<String, dynamic>?;
              return Card(child: ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text('${r['request_type'] ?? 'change'} → ${plan?['name'] ?? 'Plan'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${r['status'] ?? 'pending'} • ${r['payment_status'] ?? ''} • ${r['created_at'] ?? ''}'),
              ));
            }),
          ]);
        },
      ),
    );
  }
}
