import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/locked_feature.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  late Future<Map<String, dynamic>> _future;
  bool _saving = false;

  @override
  void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() => context.read<WorkspaceController>().storeApi.paymentGateways(context.read<WorkspaceController>().activeStoreToken!);
  Future<void> _refresh() async {
    final next = _load();
    setState(() { _future = next; });
    await next;
  }

  Future<void> _edit(Map<String, dynamic> gateway) async {
    final key = gateway['key'].toString();
    bool active = gateway['is_active'] == true;
    String mode = gateway['mode']?.toString() ?? (key == 'cod' ? 'offline' : 'live');
    final fields = _credentialFields(key);
    final controllers = {for (final f in fields) f: TextEditingController()};
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(gateway['label']?.toString() ?? key),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable'), value: active, onChanged: (v) => setDialogState(() => active = v)),
        DropdownButtonFormField<String>(value: mode, decoration: const InputDecoration(labelText: 'Mode'), items: const [DropdownMenuItem(value: 'offline', child: Text('Offline')), DropdownMenuItem(value: 'live', child: Text('Live')), DropdownMenuItem(value: 'sandbox', child: Text('Sandbox'))], onChanged: (v) => setDialogState(() => mode = v ?? mode)),
        const SizedBox(height: 12),
        for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controllers[f], decoration: InputDecoration(labelText: f.replaceAll('_', ' '), hintText: 'Leave blank to keep existing'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'is_active': active, 'mode': mode, 'credentials': {for (final e in controllers.entries) e.key: e.value.text.trim()}}), child: const Text('Save'))],
    )));
    if (result == null) return;
    try {
      setState(() => _saving = true);
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updatePaymentGateways(workspace.activeStoreToken!, {key: result});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment method saved.')));
      await _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  List<String> _credentialFields(String key) {
    switch (key) {
      case 'manual_payment': return ['instructions', 'account_number'];
      case 'bkash_api': return ['app_key', 'app_secret', 'username', 'password'];
      case 'sslcommerz_api': return ['store_id', 'store_password'];
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: Stack(children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            return ListView(padding: const EdgeInsets.all(12), children: [
              const Padding(padding: EdgeInsets.all(8), child: Text('Payment gateways follow same package rules as web admin. Locked gateways remain visible for upgrade clarity.', style: TextStyle(color: AppTheme.muted))),
              for (final gateway in items) LockedFeatureSurface(
                locked: gateway['locked'] == true,
                title: gateway['label']?.toString() ?? gateway['key'].toString(),
                requiredPackage: lockedRequiredPackage(gateway['required_plan'], fallback: 'Scale'),
                borderRadius: 18,
                child: Card(child: ListTile(
                  leading: Icon(gateway['locked'] == true ? Icons.lock_rounded : Icons.payments_outlined, color: gateway['locked'] == true ? const Color(0xFFDC2626) : AppTheme.primary),
                  title: Text(gateway['label']?.toString() ?? gateway['key'].toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${gateway['is_active'] == true ? 'Enabled' : 'Disabled'} • ${gateway['mode'] ?? 'live'}${gateway['locked'] == true ? '\nAvailable in ${lockedRequiredPackage(gateway['required_plan'], fallback: 'Scale')} plan' : ''}'),
                  isThreeLine: gateway['locked'] == true,
                  trailing: Icon(gateway['locked'] == true ? Icons.lock_rounded : Icons.chevron_right),
                  onTap: gateway['locked'] == true ? () => LockedFeatureNotice.show(context, title: gateway['label']?.toString() ?? gateway['key'].toString(), requiredPackage: lockedRequiredPackage(gateway['required_plan'], fallback: 'Scale')) : () => _edit(gateway),
                )),
              ),
            ]);
          },
        ),
        if (_saving) Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}