import 'dart:async';

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
  int? _orderStatusId;
  String _paymentStatus = 'all';
  Timer? _searchDebounce;
  late Future<Map<String, dynamic>> _future;
  List<_OrderStatusOption> _orderStatuses = const [];
  bool _loadingStatuses = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadOrderStatuses();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.orders(
      workspace.activeStoreToken!,
      search: _search.text,
      status: _status,
      orderStatusId: _orderStatusId,
      paymentStatus: _paymentStatus,
    );
  }

  Future<void> _loadOrderStatuses() async {
    try {
      final workspace = context.read<WorkspaceController>();
      final response =
          await workspace.storeApi.orderStatuses(workspace.activeStoreToken!);
      final rows = (response['data'] as List<dynamic>? ?? []);
      final statuses = rows
          .whereType<Map<String, dynamic>>()
          .map(_OrderStatusOption.fromJson)
          .where((status) => status.id > 0 && status.name.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _orderStatuses = statuses;
        _loadingStatuses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStatuses = false);
    }
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420), _refresh);
  }

  void _clearSearch() {
    if (_search.text.isEmpty) return;
    _search.clear();
    _refresh();
  }

  Future<void> _trashOrder(Map<String, dynamic> order) async {
    final id = int.tryParse(order['id']?.toString() ?? '');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move order #$id to trash?'),
        content: const Text(
            'This order will be hidden from the normal order list. You can restore it from Trash Center.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move to trash')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final workspace = context.read<WorkspaceController>();
      final res =
          await workspace.storeApi.trashOrder(workspace.activeStoreToken!, id);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(res['message']?.toString() ?? 'Order moved to trash.')));
      _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _copy(String label, Object? value) async {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Live search order, phone, transaction',
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearSearch),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _refresh(),
              ),
            ),
            _buildFilters(),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(snapshot.error.toString(),
                                textAlign: TextAlign.center)));
                  final items =
                      (snapshot.data?['data'] as List<dynamic>? ?? []);
                  if (items.isEmpty)
                    return _EmptyOrders(onReset: _resetFilters);
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final order = items[index] as Map<String, dynamic>;
                        final statusText =
                            order['order_status']?['name']?.toString() ??
                                order['status']?.toString() ??
                                'N/A';
                        final statusColor = _parseColor(
                            order['order_status']?['color']?.toString());
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => OrderDetailPage(
                                          orderId: int.parse(
                                              order['id'].toString()))));
                              _refresh();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(
                                              '#${order['id']} • ${order['customer_name'] ?? 'Customer'}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16))),
                                      Text('৳ ${order['total'] ?? '0'}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _Badge(
                                          text: statusText,
                                          color: statusColor == null
                                              ? null
                                              : statusColor.withOpacity(.12),
                                          textColor: statusColor),
                                      _Badge(
                                          text: order['payment_status']
                                                  ?.toString() ??
                                              'unpaid',
                                          color:
                                              order['payment_status'] == 'paid'
                                                  ? const Color(0xFFE8F6EE)
                                                  : const Color(0xFFFFF3D9)),
                                      _Badge(
                                          text: order['payment_method']
                                                  ?.toString() ??
                                              'payment'),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(order['mobile']?.toString() ?? '',
                                      style: const TextStyle(
                                          color: AppTheme.muted)),
                                  Text(order['address']?.toString() ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppTheme.muted)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                          onPressed: () =>
                                              _copy('Phone', order['mobile']),
                                          icon:
                                              const Icon(Icons.copy, size: 16),
                                          label: const Text('Phone')),
                                      TextButton.icon(
                                          onPressed: () => _copy(
                                              'Address', order['address']),
                                          icon:
                                              const Icon(Icons.copy, size: 16),
                                          label: const Text('Address')),
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'trash')
                                            _trashOrder(order);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'trash',
                                              child: Text('Move to Trash')),
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
      ),
    );
  }

  Widget _buildFilters() {
    final statusChips = <Widget>[
      _FilterChip(
          label: 'All orders',
          selected: _orderStatusId == null && _status == 'all',
          onTap: () => _setStatus('all')),
      if (_loadingStatuses)
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      if (!_loadingStatuses && _orderStatuses.isNotEmpty)
        for (final status in _orderStatuses)
          _FilterChip(
            label: status.name,
            selected: _orderStatusId == status.id,
            onTap: () => _setOrderStatus(status.id),
          ),
      if (!_loadingStatuses && _orderStatuses.isEmpty) ...[
        _FilterChip(
            label: 'Pending',
            selected: _status == 'pending',
            onTap: () => _setStatus('pending')),
        _FilterChip(
            label: 'Processing',
            selected: _status == 'processing',
            onTap: () => _setStatus('processing')),
        _FilterChip(
            label: 'Completed',
            selected: _status == 'completed',
            onTap: () => _setStatus('completed')),
        _FilterChip(
            label: 'Cancelled',
            selected: _status == 'cancelled',
            onTap: () => _setStatus('cancelled')),
      ],
      const SizedBox(width: 10),
      _FilterChip(
          label: 'Payment: All',
          selected: _paymentStatus == 'all',
          onTap: () => _setPayment('all')),
      _FilterChip(
          label: 'Paid',
          selected: _paymentStatus == 'paid',
          onTap: () => _setPayment('paid')),
      _FilterChip(
          label: 'Unpaid',
          selected: _paymentStatus == 'unpaid',
          onTap: () => _setPayment('unpaid')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: statusChips),
    );
  }

  void _setStatus(String value) {
    setState(() {
      _status = value;
      _orderStatusId = null;
    });
    _refresh();
  }

  void _setOrderStatus(int id) {
    setState(() {
      _orderStatusId = _orderStatusId == id ? null : id;
      _status = 'all';
    });
    _refresh();
  }

  void _setPayment(String value) {
    setState(() => _paymentStatus = value);
    _refresh();
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _status = 'all';
      _orderStatusId = null;
      _paymentStatus = 'all';
    });
    _refresh();
  }

  Color? _parseColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

class _OrderStatusOption {
  const _OrderStatusOption({required this.id, required this.name});

  final int id;
  final String name;

  factory _OrderStatusOption.fromJson(Map<String, dynamic> json) {
    return _OrderStatusOption(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.primary.withOpacity(.16),
        labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? AppTheme.primary : null),
        side: BorderSide(
            color: selected
                ? AppTheme.primary.withOpacity(.45)
                : Colors.black.withOpacity(.06)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color, this.textColor});
  final String text;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color ?? const Color(0xFFF2F5F6),
          borderRadius: BorderRadius.circular(99)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: textColor)),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppTheme.infoGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppTheme.primary, size: 30),
            ),
            const SizedBox(height: 14),
            const Text('No matching orders found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
                'Try another search keyword, order status or payment filter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 14),
            FilledButton.tonal(
                onPressed: onReset, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
