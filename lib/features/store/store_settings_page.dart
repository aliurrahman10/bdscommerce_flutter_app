import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  late Future<Map<String, dynamic>> _future;
  final _storeName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _currency = TextEditingController(text: 'BDT');
  final _whatsappOrderMessageTemplate = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _storeName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _currency.dispose();
    _whatsappOrderMessageTemplate.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.settings(workspace.activeStoreToken!);
  }

  void _fill(Map<String, dynamic> settings) {
    if (_loaded) return;
    _loaded = true;
    _storeName.text = settings['store_name']?.toString() ?? '';
    _phone.text = settings['phone']?.toString() ?? '';
    _email.text = settings['email']?.toString() ?? '';
    _address.text = settings['address']?.toString() ?? '';
    _currency.text = settings['currency']?.toString() ?? 'BDT';
    _whatsappOrderMessageTemplate.text = settings['whatsapp_order_message_template']?.toString() ?? 'আসসালামু আলাইকুম, আপনার অর্ডার #{order_id} সম্পর্কে যোগাযোগ করছি। মোট: ৳ {total}। ধন্যবাদ।';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updateSettings(workspace.activeStoreToken!, {
        'store_name': _storeName.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'currency': _currency.text.trim(),
        'whatsapp_order_message_template': _whatsappOrderMessageTemplate.text.trim(),
      });
      _loaded = false;
      setState(() {
        _future = _load();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Settings')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final settings = snapshot.data?['settings'] as Map<String, dynamic>? ?? {};
          _fill(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Basic Store Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      TextField(controller: _storeName, decoration: const InputDecoration(labelText: 'Store name')),
                      const SizedBox(height: 12),
                      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone / WhatsApp')),
                      const SizedBox(height: 12),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(controller: _address, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Address')),
                      const SizedBox(height: 12),
                      TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Currency')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _whatsappOrderMessageTemplate,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp order message',
                          helperText: 'Use {order_id}, {customer_name}, {total}, {status}, {payment_status}, {store_name}',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                          label: Text(_saving ? 'Saving...' : 'Save settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Only mobile-safe settings are editable here. WhatsApp order message supports placeholders like {order_id}, {customer_name}, {total}, {status}, {payment_status}, {store_name}. Advanced design, payment and builder settings should stay in desktop admin panel.', style: TextStyle(color: Colors.grey)),
            ],
          );
        },
      ),
    );
  }
}
