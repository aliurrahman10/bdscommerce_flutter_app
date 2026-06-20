import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'coupon_form_page.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() { super.initState(); _future = _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.coupons(workspace.activeStoreToken!, search: _search.text);
  }
  void _refresh() => setState(() => _future = _load());

  Future<void> _delete(Map<String, dynamic> coupon) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete coupon?'), content: Text('Delete ${coupon['code']}?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.deleteCoupon(workspace.activeStoreToken!, int.parse(coupon['id'].toString()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon deleted.')));
      _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _toggle(Map<String, dynamic> coupon) async {
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updateCoupon(workspace.activeStoreToken!, int.parse(coupon['id'].toString()), {'status': !(coupon['status'] == true)});
      _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _openForm({Map<String, dynamic>? coupon}) async {
    final ok = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CouponFormPage(coupon: coupon)));
    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Add')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search coupon code'), onSubmitted: (_) => _refresh())),
        Expanded(child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            if (items.isEmpty) return const Center(child: Text('No coupons found.'));
            return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), itemCount: items.length,
              itemBuilder: (_, i) {
                final coupon = items[i];
                final active = coupon['status'] == true;
                final type = coupon['type']?.toString() == 'percent' ? '%' : '৳';
                return Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: active ? const Color(0xFFE8F6EE) : const Color(0xFFFFF3D9), child: Icon(Icons.confirmation_number_outlined, color: active ? AppTheme.primary : Colors.orange)),
                  title: Text(coupon['code']?.toString() ?? 'COUPON', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${coupon['type']} discount: $type ${coupon['value']} • Min: ৳ ${coupon['min_subtotal'] ?? 0}\n${active ? 'Active' : 'Inactive'}${coupon['free_shipping'] == true ? ' • Free shipping' : ''}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _openForm(coupon: coupon); if (v == 'toggle') _toggle(coupon); if (v == 'delete') _delete(coupon); }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'toggle', child: Text(active ? 'Disable' : 'Enable')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]),
                  onTap: () => _openForm(coupon: coupon),
                ));
              },
            ));
          },
        )),
      ]),
    );
  }
}
