import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class CouponFormPage extends StatefulWidget {
  const CouponFormPage({super.key, this.coupon});
  final Map<String, dynamic>? coupon;

  @override
  State<CouponFormPage> createState() => _CouponFormPageState();
}

class _CouponFormPageState extends State<CouponFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minSubtotal = TextEditingController(text: '0');
  final _maxDiscount = TextEditingController();
  final _usageLimit = TextEditingController();
  final _perUserLimit = TextEditingController();
  final _startAt = TextEditingController();
  final _endAt = TextEditingController();

  String _type = 'fixed';
  bool _active = true;
  bool _freeShipping = false;
  bool _firstOrderOnly = false;
  bool _stackable = false;
  bool _saving = false;

  bool get _isEdit => widget.coupon != null;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    if (c != null) {
      _code.text = c['code']?.toString() ?? '';
      _type = c['type']?.toString() == 'percent' ? 'percent' : 'fixed';
      _value.text = c['value']?.toString() ?? '';
      _minSubtotal.text = c['min_subtotal']?.toString() ?? '0';
      _maxDiscount.text = c['max_discount']?.toString() ?? '';
      _usageLimit.text = c['usage_limit']?.toString() ?? '';
      _perUserLimit.text = c['per_user_limit']?.toString() ?? '';
      _startAt.text = c['start_at']?.toString() ?? '';
      _endAt.text = c['end_at']?.toString() ?? '';
      _active = c['status'] == true;
      _freeShipping = c['free_shipping'] == true;
      _firstOrderOnly = c['first_order_only'] == true;
      _stackable = c['stackable'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _value, _minSubtotal, _maxDiscount, _usageLimit, _perUserLimit, _startAt, _endAt]) { c.dispose(); }
    super.dispose();
  }

  Map<String, dynamic> _payload() => {
    'code': _code.text.trim().toUpperCase(),
    'type': _type,
    'value': _value.text.trim(),
    'min_subtotal': _minSubtotal.text.trim().isEmpty ? '0' : _minSubtotal.text.trim(),
    if (_maxDiscount.text.trim().isNotEmpty) 'max_discount': _maxDiscount.text.trim(),
    if (_usageLimit.text.trim().isNotEmpty) 'usage_limit': int.tryParse(_usageLimit.text.trim()) ?? 0,
    if (_perUserLimit.text.trim().isNotEmpty) 'per_user_limit': int.tryParse(_perUserLimit.text.trim()) ?? 0,
    if (_startAt.text.trim().isNotEmpty) 'start_at': _startAt.text.trim(),
    if (_endAt.text.trim().isNotEmpty) 'end_at': _endAt.text.trim(),
    'status': _active,
    'free_shipping': _freeShipping,
    'first_order_only': _firstOrderOnly,
    'stackable': _stackable,
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      if (_isEdit) {
        await workspace.storeApi.updateCoupon(token, int.parse(widget.coupon!['id'].toString()), _payload());
      } else {
        await workspace.storeApi.createCoupon(token, _payload());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon saved.')));
      Navigator.of(context).pop(true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Coupon' : 'Add Coupon')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(_saving ? 'Saving...' : 'Save Coupon')))),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Basic Discount', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Coupon code *'), validator: (v) => v == null || v.trim().isEmpty ? 'Code is required' : null),
            const SizedBox(height: 12),
            SegmentedButton<String>(segments: const [ButtonSegment(value: 'fixed', label: Text('Fixed')), ButtonSegment(value: 'percent', label: Text('Percent'))], selected: {_type}, onSelectionChanged: (v) => setState(() => _type = v.first)),
            const SizedBox(height: 12),
            TextFormField(controller: _value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _type == 'percent' ? 'Discount percent *' : 'Discount amount *'), validator: (v) => v == null || v.trim().isEmpty ? 'Value is required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _minSubtotal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum subtotal')),
            const SizedBox(height: 12),
            TextFormField(controller: _maxDiscount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum discount')),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Limit & Schedule', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(controller: _usageLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Usage limit')),
            const SizedBox(height: 12),
            TextFormField(controller: _perUserLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per user limit')),
            const SizedBox(height: 12),
            TextFormField(controller: _startAt, decoration: const InputDecoration(labelText: 'Start at', hintText: '2026-06-17 10:00:00')),
            const SizedBox(height: 12),
            TextFormField(controller: _endAt, decoration: const InputDecoration(labelText: 'End at', hintText: '2026-06-30 23:59:59')),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
            SwitchListTile(title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v)),
            SwitchListTile(title: const Text('Free shipping'), value: _freeShipping, onChanged: (v) => setState(() => _freeShipping = v)),
            SwitchListTile(title: const Text('First order only'), value: _firstOrderOnly, onChanged: (v) => setState(() => _firstOrderOnly = v)),
            SwitchListTile(title: const Text('Stackable'), value: _stackable, onChanged: (v) => setState(() => _stackable = v)),
          ]))),
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('Advanced product/category targeting remains available in web admin.', style: TextStyle(color: AppTheme.muted))),
        ]),
      ),
    );
  }
}
