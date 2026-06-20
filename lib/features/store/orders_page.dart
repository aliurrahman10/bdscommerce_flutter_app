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
  bool _commandCenterExpanded = false;

  String? _whatsAppMessageTemplate;
  String _storeName = 'our store';

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus.trim().isEmpty ? 'all' : widget.initialStatus.trim();
    _paymentStatus = widget.initialPaymentStatus.trim().isEmpty ? 'all' : widget.initialPaymentStatus.trim();
    _future = _load();
    _loadOrderStatuses();
    _loadWhatsAppTemplate();
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

  Future<void> _loadWhatsAppTemplate() async {
    try {
      final workspace = context.read<WorkspaceController>();
      final response = await workspace.storeApi.settings(workspace.activeStoreToken!);
      final settings = response['settings'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      if (!mounted) return;
      final storeName = settings['store_name']?.toString().trim();
      setState(() {
        _whatsAppMessageTemplate = settings['whatsapp_order_message_template']?.toString();
        _storeName = storeName != null && storeName.isNotEmpty ? storeName : 'our store';
      });
    } catch (_) {}
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
    final message = _whatsappMessage(order);
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

  String _whatsappMessage(Map<String, dynamic> order) {
    final template = (_whatsAppMessageTemplate ?? '').trim().isNotEmpty
        ? _whatsAppMessageTemplate!.trim()
        : 'Hello {customer_name}, your order #{order_id} is {status}. Total: {total}. - {store_name}';
    final values = <String, String>{
      'order_id': order['id']?.toString() ?? '',
      'customer_name': order['customer_name']?.toString() ?? order['name']?.toString() ?? '',
      'total': order['total']?.toString() ?? '',
      'status': order['order_status']?['name']?.toString() ?? order['status']?.toString() ?? '',
      'payment_status': order['payment_status']?.toString() ?? '',
      'store_name': _storeName,
    };
    var message = template;
    values.forEach((key, value) {
      message = message.replaceAll('{$key}', value);
    });
    return message;
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
      backgroundColor: const Color(0xFFF8FAFC), // Enterprise soft background
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _OrdersHero(
                    statusText: _activeStatusLabel(),
                    paymentStatus: _paymentStatus,
                    searchText: _search.text,
                    expanded: _commandCenterExpanded,
                    onToggle: () => setState(() => _commandCenterExpanded = !_commandCenterExpanded),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.primary.withOpacity(0.04),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.muted),
                        hintText: 'Search order, phone, or ID...',
                        hintStyle: const TextStyle(color: AppTheme.muted),
                        suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _clearSearch),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _refresh(),
                    ),
                  ),
                  _buildFilters(),
                  const Divider(height: 1, color: AppTheme.border),
                ],
              ),
            ),
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
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
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
      _FilterChip(label: 'All', selected: _orderStatusId == null && _status == 'all', onTap: () => _setStatus('all')),
      if (_loadingStatuses)
        const Padding(
          padding: EdgeInsets.only(right: 10, left: 10),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
      Container(width: 1, height: 20, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
      _FilterChip(label: 'All Payments', selected: _paymentStatus == 'all', onTap: () => _setPayment('all')),
      _FilterChip(label: 'Paid', selected: _paymentStatus == 'paid', onTap: () => _setPayment('paid'), color: AppTheme.success),
      _FilterChip(label: 'Unpaid', selected: _paymentStatus == 'unpaid', onTap: () => _setPayment('unpaid'), color: AppTheme.warning),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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

// Enterprise Command Center (Flat, no heavy gradient)
class _OrdersHero extends StatelessWidget {
  const _OrdersHero({required this.statusText, required this.paymentStatus, required this.searchText, required this.expanded, required this.onToggle});
  final String statusText;
  final String paymentStatus;
  final String searchText;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final paymentLabel = paymentStatus == 'all' ? 'All payments' : paymentStatus;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.data_usage_rounded, color: AppTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Overview', style: TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                          Text('$statusText • $paymentLabel', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600, fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppTheme.muted, size: 20),
                  ],
                ),
                if (expanded) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 8),
                    child: Text('Filters applied currently:', style: TextStyle(color: AppTheme.muted2, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroPill(icon: Icons.fact_check_outlined, text: statusText),
                      _HeroPill(icon: Icons.payments_outlined, text: paymentLabel),
                      if (searchText.trim().isNotEmpty) _HeroPill(icon: Icons.search_rounded, text: 'Search active'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppTheme.muted, size: 12),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 11)),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(child: Text(filter, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600, fontSize: 11.5))),
          Text('$visible of $total', style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ],
      ),
    );
  }
}

// Enterprise Style Order Card
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
    
    // Enterprise Soft Colors
    final activeStatusColor = statusColor ?? AppTheme.primary;
    final isPaid = paymentStatus.toLowerCase() == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), // Slightly less rounded for enterprise
        border: Border.all(color: const Color(0xFFE2E8F0)), // Light solid border
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))
        ], // Ultra-soft shadow
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section (ID & Total)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${order['id']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text(order['created_at']?.toString() ?? 'Recent', style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text('৳ ${order['total'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),

              // Middle Section (Customer Info)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: AppTheme.muted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(order['customer_name']?.toString() ?? 'Customer', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hasPhone)
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppTheme.muted),
                          const SizedBox(width: 6),
                          Text(order['mobile']?.toString() ?? '', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Badges Section (Pill style)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _SoftBadge(text: statusText, bgColor: activeStatusColor.withOpacity(0.1), textColor: activeStatusColor),
                    _SoftBadge(
                      text: paymentStatus.toUpperCase(), 
                      bgColor: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3), 
                      textColor: isPaid ? const Color(0xFF166534) : const Color(0xFF854D0E)
                    ),
                    _SoftBadge(text: order['payment_method']?.toString() ?? 'payment', bgColor: AppTheme.primary.withOpacity(0.05), textColor: AppTheme.muted),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Action Bar (Minimal)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.muted, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)))),
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Container(width: 1, height: 24, color: const Color(0xFFF1F5F9)),
                  if (hasPhone) ...[
                    IconButton(
                      onPressed: onCall,
                      icon: const Icon(Icons.call_outlined, size: 18, color: AppTheme.primary),
                      tooltip: 'Call Customer',
                    ),
                    IconButton(
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF25D366)),
                      tooltip: 'WhatsApp',
                    ),
                  ],
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.muted),
                    onSelected: (value) {
                      if (value == 'copy_phone') onCopyPhone();
                      if (value == 'copy_address') onCopyAddress();
                      if (value == 'trash') onTrash();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'copy_phone', child: Text('Copy Phone', style: TextStyle(fontSize: 13))),
                      PopupMenuItem(value: 'copy_address', child: Text('Copy Address', style: TextStyle(fontSize: 13))),
                      PopupMenuItem(value: 'trash', child: Text('Move to Trash', style: TextStyle(fontSize: 13, color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.text, required this.bgColor, required this.textColor});
  final String text;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)), // Subtle rounded corners
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5)),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? activeColor : AppTheme.muted,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.inbox_outlined, color: AppTheme.muted, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No orders found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.text)),
            const SizedBox(height: 6),
            const Text('Try adjusting your filters or search terms.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(onPressed: onReset, child: const Text('Clear all filters')),
          ],
        ),
      ),
    );
  }
}