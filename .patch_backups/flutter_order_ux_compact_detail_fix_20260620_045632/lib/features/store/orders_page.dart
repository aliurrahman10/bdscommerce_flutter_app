import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, this.initialStatus = 'all', this.initialPaymentStatus = 'all'});

  final String initialStatus;
  final String initialPaymentStatus;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _search = TextEditingController();
  late String _status;
  int? _orderStatusId;
  late String _paymentStatus;
  Timer? _searchDebounce;
  late Future<Map<String, dynamic>> _future;
  List<_OrderStatusOption> _orderStatuses = const [];
  bool _loadingStatuses = true;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus.trim().isEmpty ? 'all' : widget.initialStatus.trim();
    _paymentStatus = widget.initialPaymentStatus.trim().isEmpty ? 'all' : widget.initialPaymentStatus.trim();
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
      final response = await workspace.storeApi.orderStatuses(workspace.activeStoreToken!);
      final rows = (response['data'] as List<dynamic>? ?? []);
      final statuses = rows
          .whereType<Map<String, dynamic>>()
          .map(_OrderStatusOption.fromJson)
          .where((status) => status.id > 0 && status.name.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _orderStatuses = statuses;
        if (_orderStatusId == null && _status != 'all') {
          final normalizedInitial = _normalize(_status);
          for (final status in statuses) {
            if (_normalize(status.name) == normalizedInitial) {
              _orderStatusId = status.id;
              _status = 'all';
              break;
            }
          }
        }
        _loadingStatuses = false;
      });
      if (_orderStatusId != null) _refresh();
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

  Future<void> _call(Object? rawPhone) async {
    final phone = rawPhone?.toString().replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open phone dialer.')));
    }
  }

  Future<void> _whatsapp(Map<String, dynamic> order) async {
    final number = _waNumber(order['mobile']);
    if (number.isEmpty) return;
    final message = 'Assalamu alaikum, order #${order['id']} regarding your order from our store.';
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  String _waNumber(Object? rawPhone) {
    var phone = rawPhone?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (phone.startsWith('0') && phone.length == 11) phone = '88$phone';
    return phone;
  }

  String _normalize(String value) {
    final key = value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    if (key == 'complete') return 'completed';
    if (key == 'cancelled') return 'canceled';
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: SafeArea(
        child: Column(
          children: [
            _OrdersHero(statusText: _activeStatusLabel(), paymentStatus: _paymentStatus, searchText: _search.text),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Live search order, phone, transaction',
                  suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: _clearSearch),
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
                  if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final items = (snapshot.data?['data'] as List<dynamic>? ?? []);
                  final meta = snapshot.data?['meta'] as Map<String, dynamic>? ?? const {};
                  if (items.isEmpty) return _EmptyOrders(onReset: _resetFilters);
                  return Column(
                    children: [
                      _ResultSummary(visible: items.length, total: int.tryParse(meta['total']?.toString() ?? '') ?? items.length, filter: _activeFilterSummary()),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async => _refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
                            itemCount: items.length,
                            itemBuilder: (_, index) {
                              final order = items[index] as Map<String, dynamic>;
                              return _PremiumOrderCard(
                                order: order,
                                statusColor: _parseColor(order['order_status']?['color']?.toString()),
                                statusText: order['order_status']?['name']?.toString() ?? order['status']?.toString() ?? 'N/A',
                                onTap: () async {
                                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: int.parse(order['id'].toString()))));
                                  _refresh();
                                },
                                onCall: () => _call(order['mobile']),
                                onWhatsApp: () => _whatsapp(order),
                                onCopyPhone: () => _copy('Phone', order['mobile']),
                                onCopyAddress: () => _copy('Address', order['address']),
                                onTrash: () => _trashOrder(order),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
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
      _FilterChip(label: 'All orders', selected: _orderStatusId == null && _status == 'all', onTap: () => _setStatus('all')),
      if (_loadingStatuses)
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      if (!_loadingStatuses && _orderStatuses.isNotEmpty)
        for (final status in _orderStatuses)
          _FilterChip(
            label: status.name,
            selected: _orderStatusId == status.id,
            color: status.color,
            onTap: () => _setOrderStatus(status.id),
          ),
      if (!_loadingStatuses && _orderStatuses.isEmpty) ...[
        _FilterChip(label: 'Pending', selected: _status == 'pending', onTap: () => _setStatus('pending')),
        _FilterChip(label: 'Processing', selected: _status == 'processing', onTap: () => _setStatus('processing')),
        _FilterChip(label: 'Completed', selected: _status == 'completed', onTap: () => _setStatus('completed')),
        _FilterChip(label: 'Cancelled', selected: _status == 'cancelled', onTap: () => _setStatus('cancelled')),
      ],
      const SizedBox(width: 10),
      _FilterChip(label: 'Payment: All', selected: _paymentStatus == 'all', onTap: () => _setPayment('all')),
      _FilterChip(label: 'Paid', selected: _paymentStatus == 'paid', onTap: () => _setPayment('paid'), color: AppTheme.success),
      _FilterChip(label: 'Unpaid', selected: _paymentStatus == 'unpaid', onTap: () => _setPayment('unpaid'), color: AppTheme.warning),
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

  String _activeStatusLabel() {
    if (_orderStatusId != null) {
      for (final status in _orderStatuses) {
        if (status.id == _orderStatusId) return status.name;
      }
    }
    return _status == 'all' ? 'All orders' : _status;
  }

  String _activeFilterSummary() {
    final parts = <String>[];
    if (_search.text.trim().isNotEmpty) parts.add('Search: ${_search.text.trim()}');
    if (_activeStatusLabel() != 'All orders') parts.add('Status: ${_activeStatusLabel()}');
    if (_paymentStatus != 'all') parts.add('Payment: $_paymentStatus');
    return parts.isEmpty ? 'Showing latest orders' : parts.join(' • ');
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
  const _OrderStatusOption({required this.id, required this.name, this.color});

  final int id;
  final String name;
  final Color? color;

  factory _OrderStatusOption.fromJson(Map<String, dynamic> json) {
    return _OrderStatusOption(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      color: _parseHexColor(json['color']?.toString()),
    );
  }

  static Color? _parseHexColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

class _OrdersHero extends StatelessWidget {
  const _OrdersHero({required this.statusText, required this.paymentStatus, required this.searchText});
  final String statusText;
  final String paymentStatus;
  final String searchText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.glowShadow(),
      ),
      child: Stack(
        children: [
          Positioned(right: -18, top: -22, child: Icon(Icons.receipt_long_rounded, color: Colors.white.withOpacity(.10), size: 100)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.18))),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(.18))),
                    child: const Text('Live control', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Order Command Center', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.12)),
              const SizedBox(height: 7),
              Text('Search, filter, call, WhatsApp and update orders faster from one polished mobile workspace.', style: TextStyle(color: Colors.white.withOpacity(.82), fontWeight: FontWeight.w600, height: 1.38)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroPill(icon: Icons.fact_check_rounded, text: statusText),
                  _HeroPill(icon: Icons.payments_rounded, text: paymentStatus == 'all' ? 'All payments' : paymentStatus),
                  if (searchText.trim().isNotEmpty) _HeroPill(icon: Icons.search_rounded, text: 'Live search'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(.16))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
      ]),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.visible, required this.total, required this.filter});
  final int visible;
  final int total;
  final String filter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        children: [
          Expanded(child: Text(filter, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700, fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(.08), borderRadius: BorderRadius.circular(999)),
            child: Text('$visible/$total', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _PremiumOrderCard extends StatelessWidget {
  const _PremiumOrderCard({
    required this.order,
    required this.statusText,
    required this.onTap,
    required this.onCall,
    required this.onWhatsApp,
    required this.onCopyPhone,
    required this.onCopyAddress,
    required this.onTrash,
    this.statusColor,
  });

  final Map<String, dynamic> order;
  final String statusText;
  final Color? statusColor;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopyPhone;
  final VoidCallback onCopyAddress;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final paymentStatus = order['payment_status']?.toString() ?? 'unpaid';
    final hasPhone = (order['mobile']?.toString() ?? '').trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: _statusGradient(statusText), borderRadius: BorderRadius.circular(17)),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${order['id']} • ${order['customer_name'] ?? 'Customer'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                    const SizedBox(height: 3),
                    Text(order['created_at']?.toString() ?? 'Recent order', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('৳ ${order['total'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
              ]),
              const SizedBox(height: 11),
              Wrap(spacing: 7, runSpacing: 7, children: [
                _Badge(text: statusText, color: (statusColor ?? AppTheme.primary).withOpacity(.11), textColor: statusColor ?? AppTheme.primary),
                _Badge(text: paymentStatus, color: paymentStatus == 'paid' ? const Color(0xFFE8F6EE) : const Color(0xFFFFF3D9), textColor: paymentStatus == 'paid' ? AppTheme.success : const Color(0xFFA16207)),
                _Badge(text: order['payment_method']?.toString() ?? 'payment'),
              ]),
              const SizedBox(height: 10),
              _InlineInfo(icon: Icons.phone_outlined, text: order['mobile']?.toString() ?? 'No phone'),
              _InlineInfo(icon: Icons.location_on_outlined, text: order['address']?.toString() ?? 'No address'),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: hasPhone ? onCall : null, icon: const Icon(Icons.call_rounded, size: 17), label: const Text('Call'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: hasPhone ? onWhatsApp : null, icon: const Icon(Icons.chat_rounded, size: 17), label: const Text('WhatsApp'))),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: onTap, icon: const Icon(Icons.open_in_new_rounded)),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'copy_phone') onCopyPhone();
                    if (value == 'copy_address') onCopyAddress();
                    if (value == 'trash') onTrash();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'copy_phone', child: Text('Copy phone')),
                    PopupMenuItem(value: 'copy_address', child: Text('Copy address')),
                    PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
                  ],
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Gradient _statusGradient(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('complete')) return AppTheme.successGradient;
    if (normalized.contains('process')) return AppTheme.infoGradient;
    if (normalized.contains('cancel')) return AppTheme.dangerGradient;
    if (normalized.contains('pending')) return AppTheme.warningGradient;
    return AppTheme.premiumGradient;
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(icon, color: AppTheme.muted2, size: 16),
        const SizedBox(width: 7),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600, fontSize: 12.5))),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: color == null ? null : CircleAvatar(radius: 5, backgroundColor: color),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: activeColor.withOpacity(.16),
        labelStyle: TextStyle(fontWeight: FontWeight.w800, color: selected ? activeColor : null),
        side: BorderSide(color: selected ? activeColor.withOpacity(.45) : Colors.black.withOpacity(.06)),
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
      decoration: BoxDecoration(color: color ?? const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textColor)),
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
              child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 14),
            const Text('No matching orders found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Try another search keyword, order status or payment filter.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: onReset, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
