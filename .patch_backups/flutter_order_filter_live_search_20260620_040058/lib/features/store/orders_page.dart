import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _search = TextEditingController();
  String _status = 'all';
  String _paymentStatus = 'all';
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.orders(
      workspace.activeStoreToken!,
      search: _search.text,
      status: _status,
      paymentStatus: _paymentStatus,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }


  Future<void> _trashOrder(Map<String, dynamic> order) async {
    final id = int.tryParse(order['id']?.toString() ?? '');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move order #$id to trash?'),
        content: const Text('This order will be hidden from the normal order list. You can restore it from Trash Center.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move to trash')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.trashOrder(workspace.activeStoreToken!, id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Order moved to trash.')));
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _copy(String label, Object? value) async {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search order, phone, transaction'),
              onSubmitted: (_) => _refresh(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _status == 'all', onTap: () => _setStatus('all')),
                _FilterChip(label: 'Pending', selected: _status == 'pending', onTap: () => _setStatus('pending')),
                _FilterChip(label: 'Processing', selected: _status == 'processing', onTap: () => _setStatus('processing')),
                _FilterChip(label: 'Completed', selected: _status == 'completed', onTap: () => _setStatus('completed')),
                _FilterChip(label: 'Cancelled', selected: _status == 'cancelled', onTap: () => _setStatus('cancelled')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Paid', selected: _paymentStatus == 'paid', onTap: () => _setPayment('paid')),
                _FilterChip(label: 'Unpaid', selected: _paymentStatus == 'unpaid', onTap: () => _setPayment('unpaid')),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                final items = (snapshot.data?['data'] as List<dynamic>? ?? []);
                if (items.isEmpty) return const Center(child: Text('No orders found.'));
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final order = items[index] as Map<String, dynamic>;
                      final statusText = order['order_status']?['name']?.toString() ?? order['status']?.toString() ?? 'N/A';
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: int.parse(order['id'].toString()))));
                            _refresh();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('#${order['id']} • ${order['customer_name'] ?? 'Customer'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                                    Text('৳ ${order['total'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _Badge(text: statusText),
                                    _Badge(text: order['payment_status']?.toString() ?? 'unpaid', color: order['payment_status'] == 'paid' ? const Color(0xFFE8F6EE) : const Color(0xFFFFF3D9)),
                                    _Badge(text: order['payment_method']?.toString() ?? 'payment'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(order['mobile']?.toString() ?? '', style: const TextStyle(color: AppTheme.muted)),
                                Text(order['address']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton.icon(onPressed: () => _copy('Phone', order['mobile']), icon: const Icon(Icons.copy, size: 16), label: const Text('Phone')),
                                    TextButton.icon(onPressed: () => _copy('Address', order['address']), icon: const Icon(Icons.copy, size: 16), label: const Text('Address')),
                                    const Spacer(),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'trash') _trashOrder(order);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
                                      ],
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setStatus(String value) {
    setState(() => _status = value);
    _refresh();
  }

  void _setPayment(String value) {
    setState(() => _paymentStatus = _paymentStatus == value ? 'all' : value);
    _refresh();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color ?? const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
