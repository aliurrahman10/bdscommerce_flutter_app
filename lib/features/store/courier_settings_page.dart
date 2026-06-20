import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/locked_feature.dart';

class CourierSettingsPage extends StatefulWidget {
  const CourierSettingsPage({super.key});

  @override
  State<CourierSettingsPage> createState() => _CourierSettingsPageState();
}

class _CourierSettingsPageState extends State<CourierSettingsPage> {
  late Future<Map<String, dynamic>> _future;
  bool _saving = false;

  @override
  void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() => context.read<WorkspaceController>().storeApi.couriers(context.read<WorkspaceController>().activeStoreToken!);
  void _refresh() => setState(() => _future = _load());

  Future<void> _edit(Map<String, dynamic> courier) async {
    final key = courier['key'].toString();
    bool active = courier['is_active'] == true;
    String mode = courier['mode']?.toString() ?? 'live';
    final fields = _credentialFields(key);
    final controllers = {for (final f in fields) f: TextEditingController()};
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(courier['label']?.toString() ?? key),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable'), value: active, onChanged: (v) => setDialogState(() => active = v)),
        DropdownButtonFormField<String>(value: mode, decoration: const InputDecoration(labelText: 'Mode'), items: const [DropdownMenuItem(value: 'live', child: Text('Live')), DropdownMenuItem(value: 'sandbox', child: Text('Sandbox'))], onChanged: (v) => setDialogState(() => mode = v ?? mode)),
        const SizedBox(height: 12),
        for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controllers[f], decoration: InputDecoration(labelText: f.replaceAll('_', ' '), hintText: 'Leave blank to keep existing'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'is_active': active, 'mode': mode, 'credentials': {for (final e in controllers.entries) e.key: e.value.text.trim()}}), child: const Text('Save'))],
    )));
    if (result == null) return;
    try {
      setState(() => _saving = true);
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updateCouriers(workspace.activeStoreToken!, {key: result});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Courier settings saved.')));
      _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  List<String> _credentialFields(String key) {
    switch (key) {
      case 'pathao': return ['client_id', 'client_secret', 'username', 'password', 'store_id', 'city_id', 'zone_id', 'area_id'];
      case 'steadfast': return ['base_url', 'api_key', 'secret_key'];
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courier Settings')),
      body: Stack(children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            return ListView(padding: const EdgeInsets.all(12), children: [
              const Padding(padding: EdgeInsets.all(8), child: Text('Courier integrations follow same package rules as web admin. Locked couriers remain visible for upgrade clarity.', style: TextStyle(color: AppTheme.muted))),
              for (final courier in items) LockedFeatureSurface(
                locked: courier['locked'] == true,
                title: courier['label']?.toString() ?? courier['key'].toString(),
                requiredPackage: lockedRequiredPackage(courier['required_plan'], fallback: 'Scale'),
                borderRadius: 18,
                child: Card(child: ListTile(
                  leading: Icon(courier['locked'] == true ? Icons.lock_rounded : Icons.delivery_dining_outlined, color: courier['locked'] == true ? const Color(0xFFDC2626) : AppTheme.primary),
                  title: Text(courier['label']?.toString() ?? courier['key'].toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${courier['is_active'] == true ? 'Enabled' : 'Disabled'} • ${courier['mode'] ?? 'live'}${courier['locked'] == true ? '\nAvailable in ${lockedRequiredPackage(courier['required_plan'], fallback: 'Scale')} plan' : ''}'),
                  isThreeLine: courier['locked'] == true,
                  trailing: Icon(courier['locked'] == true ? Icons.lock_rounded : Icons.chevron_right),
                  onTap: courier['locked'] == true ? () => LockedFeatureNotice.show(context, title: courier['label']?.toString() ?? courier['key'].toString(), requiredPackage: lockedRequiredPackage(courier['required_plan'], fallback: 'Scale')) : () => _edit(courier),
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