import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<Map<String, dynamic>> _future;
  int? _selectedStatus;
  String _selectedCourier = 'pathao';
  bool _updating = false;
  bool _sendingCourier = false;
  bool _checkingFraud = false;
  bool _loadingCities = false;
  bool _loadingZones = false;
  bool _loadingAreas = false;
  int? _selectedCityId;
  int? _selectedZoneId;
  int? _selectedAreaId;
  List<Map<String, dynamic>> _pathaoCities = [];
  List<Map<String, dynamic>> _pathaoZones = [];
  List<Map<String, dynamic>> _pathaoAreas = [];
  String? _whatsAppMessageTemplate;
  String _storeName = 'our store';

  final _decisionNoteCtrl = TextEditingController();
  String _decision = 'REQUIRE_OTP';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _decisionNoteCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    workspace.storeApi.markOrderRead(token, widget.orderId).catchError((_) => <String, dynamic>{});
    final results = await Future.wait([
      workspace.storeApi.showOrder(token, widget.orderId),
      workspace.storeApi.orderStatuses(token),
      workspace.storeApi.orderTools(token, widget.orderId),
      workspace.storeApi.settings(token).catchError((_) => <String, dynamic>{}),
    ]);
    final settingsResponse = results[3];
    final settings = settingsResponse['settings'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    _whatsAppMessageTemplate = settings['whatsapp_order_message_template']?.toString();
    final storeName = settings['store_name']?.toString().trim();
    _storeName = storeName != null && storeName.isNotEmpty ? storeName : 'our store';
    return {'orderResponse': results[0], 'statusesResponse': results[1], 'toolsResponse': results[2], 'settingsResponse': settingsResponse};
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
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
        : 'আসসালামু আলাইকুম, আপনার অর্ডার #{order_id} সম্পর্কে যোগাযোগ করছি। মোট: ৳ {total}। ধন্যবাদ।';
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

  int? _locationId(Map<String, dynamic> item) {
    for (final key in ['city_id', 'zone_id', 'area_id', 'id']) {
      final value = item[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _locationName(Map<String, dynamic> item) {
    for (final key in ['city_name', 'zone_name', 'area_name', 'name', 'label']) {
      final value = item[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value;
    }
    final id = _locationId(item);
    return id == null ? 'Unknown' : 'ID $id';
  }

  Future<void> _loadPathaoCities() async {
    if (_pathaoCities.isNotEmpty || _loadingCities) return;
    setState(() => _loadingCities = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.pathaoCities(workspace.activeStoreToken!);
      final data = (res['data'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
      if (mounted) setState(() => _pathaoCities = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadPathaoZones(int cityId) async {
    setState(() {
      _loadingZones = true;
      _selectedCityId = cityId;
      _selectedZoneId = null;
      _selectedAreaId = null;
      _pathaoZones = [];
      _pathaoAreas = [];
    });
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.pathaoZones(workspace.activeStoreToken!, cityId);
      final data = (res['data'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
      if (mounted) setState(() => _pathaoZones = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingZones = false);
    }
  }

  Future<void> _loadPathaoAreas(int zoneId) async {
    setState(() {
      _loadingAreas = true;
      _selectedZoneId = zoneId;
      _selectedAreaId = null;
      _pathaoAreas = [];
    });
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.pathaoAreas(workspace.activeStoreToken!, zoneId);
      final data = (res['data'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
      if (mounted) setState(() => _pathaoAreas = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == null) return;
    setState(() => _updating = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updateOrderStatus(token: workspace.activeStoreToken!, orderId: widget.orderId, orderStatusId: _selectedStatus!);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order status updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _sendCourier() async {
    setState(() => _sendingCourier = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final data = <String, dynamic>{};
      if (_selectedCourier == 'pathao') {
        if (_selectedCityId != null) data['city_id'] = _selectedCityId;
        if (_selectedZoneId != null) data['zone_id'] = _selectedZoneId;
        if (_selectedAreaId != null) data['area_id'] = _selectedAreaId;
      }
      final res = await workspace.storeApi.sendOrderToCourier(workspace.activeStoreToken!, widget.orderId, _selectedCourier, data);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Courier request completed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sendingCourier = false);
    }
  }

  Future<void> _runFraudCheck() async {
    setState(() => _checkingFraud = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final res = await workspace.storeApi.runFraudCheck(workspace.activeStoreToken!, widget.orderId);
      final suggestion = res['suggestion'] as Map<String, dynamic>? ?? {};
      final suggestedDecision = suggestion['suggested_decision']?.toString();
      if (suggestedDecision != null && suggestedDecision.isNotEmpty) _decision = suggestedDecision;
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Fraud check completed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _checkingFraud = false);
    }
  }

  Future<void> _saveFraudDecision() async {
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.saveFraudDecision(workspace.activeStoreToken!, widget.orderId, {
        'final_decision': _decision,
        'decision_note': _decisionNoteCtrl.text.trim(),
      });
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fraud decision saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _moveOrderToTrash() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move order #${widget.orderId} to trash?'),
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
      final res = await workspace.storeApi.trashOrder(workspace.activeStoreToken!, widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Order moved to trash.')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Enterprise Soft BG
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text('Order #${widget.orderId}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: AppTheme.text)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.text),
            onSelected: (value) {
              if (value == 'trash') _moveOrderToTrash();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'trash', child: Text('Move to Trash', style: TextStyle(color: AppTheme.danger))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            
            final payload = snapshot.data ?? {};
            final order = (payload['orderResponse'] as Map<String, dynamic>)['order'] as Map<String, dynamic>;
            final statuses = ((payload['statusesResponse'] as Map<String, dynamic>)['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            final tools = payload['toolsResponse'] as Map<String, dynamic>;
            final items = (order['items'] as List<dynamic>? ?? []);
            final currentStatusId = order['order_status']?['id'] is int ? order['order_status']['id'] as int : int.tryParse(order['order_status']?['id']?.toString() ?? '');
            final couriers = (tools['couriers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            final shipments = (tools['shipments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            final fraud = tools['fraud_assessment'] as Map<String, dynamic>?;
            final bottomPadding = 32 + MediaQuery.of(context).viewPadding.bottom;
            
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              children: [
                _UnifiedProfileCard(
                  order: order,
                  onCopy: _copy,
                  onCall: () => _call(order['mobile']),
                  onWhatsApp: () => _whatsapp(order),
                ),
                const SizedBox(height: 16),
                
                _StatusCard(
                  statuses: statuses,
                  currentStatusId: currentStatusId,
                  selectedStatus: _selectedStatus,
                  updating: _updating,
                  onChanged: (v) => setState(() => _selectedStatus = v),
                  onUpdate: _updateStatus,
                ),
                const SizedBox(height: 12),
                
                _CourierCard(
                  couriers: couriers,
                  shipments: shipments,
                  selectedCourier: _selectedCourier,
                  pathaoCities: _pathaoCities,
                  pathaoZones: _pathaoZones,
                  pathaoAreas: _pathaoAreas,
                  selectedCityId: _selectedCityId,
                  selectedZoneId: _selectedZoneId,
                  selectedAreaId: _selectedAreaId,
                  loadingCities: _loadingCities,
                  loadingZones: _loadingZones,
                  loadingAreas: _loadingAreas,
                  locationId: _locationId,
                  locationName: _locationName,
                  sending: _sendingCourier,
                  onCourierChanged: (v) {
                    setState(() => _selectedCourier = v);
                    if (v == 'pathao') _loadPathaoCities();
                  },
                  onCityChanged: (id) { if (id != null) _loadPathaoZones(id); },
                  onZoneChanged: (id) { if (id != null) _loadPathaoAreas(id); },
                  onAreaChanged: (id) => setState(() => _selectedAreaId = id),
                  onSend: _sendCourier,
                ),
                const SizedBox(height: 12),
                
                _FraudCard(
                  fraud: fraud,
                  checking: _checkingFraud,
                  decision: _decision,
                  noteCtrl: _decisionNoteCtrl,
                  onCheck: _runFraudCheck,
                  onDecisionChanged: (v) => setState(() => _decision = v),
                  onSaveDecision: _saveFraudDecision,
                ),
                const SizedBox(height: 24),
                
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('ORDER ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.muted2, letterSpacing: 1.2)),
                ),
                _OrderItemsTable(items: items, total: order['total']?.toString() ?? '0'),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 1. Unified Enterprise Profile Card (Replaces Hero + Customer Card)
class _UnifiedProfileCard extends StatelessWidget {
  const _UnifiedProfileCard({required this.order, required this.onCopy, required this.onCall, required this.onWhatsApp});
  final Map<String, dynamic> order;
  final Future<void> Function(String label, Object? value) onCopy;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  Color? _parseColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final statusName = order['order_status']?['name']?.toString() ?? order['status']?.toString() ?? 'N/A';
    final statusColor = _parseColor(order['order_status']?['color']?.toString()) ?? AppTheme.primary;
    final paymentStatus = order['payment_status']?.toString() ?? 'unpaid';
    final isPaid = paymentStatus.toLowerCase() == 'paid';
    final hasPhone = (order['mobile']?.toString() ?? '').trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Amount & Badges
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('৳ ${order['total'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1)),
                      const SizedBox(height: 6),
                      Text(order['created_at']?.toString() ?? 'Recent order', style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SoftBadge(text: statusName, bgColor: statusColor.withOpacity(0.12), textColor: statusColor),
                    const SizedBox(height: 6),
                    _SoftBadge(
                      text: paymentStatus.toUpperCase(), 
                      bgColor: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3), 
                      textColor: isPaid ? const Color(0xFF166534) : const Color(0xFF854D0E)
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          
          // Customer Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        order['customer_name']?.toString() ?? 'Customer', 
                        maxLines: 1, overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow(icon: Icons.phone_outlined, text: order['mobile']?.toString() ?? '', onCopy: () => onCopy('Phone', order['mobile'])),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.location_on_outlined, text: order['address']?.toString() ?? '', onCopy: () => onCopy('Address', order['address'])),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SmallDetail(label: 'Method', value: order['payment_method']?.toString() ?? 'N/A'),
                    const SizedBox(width: 16),
                    _SmallDetail(label: 'Channel', value: order['channel']?.toString() ?? 'Store'),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Buttons Bottom
          if (hasPhone) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.text, padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)))
                    ),
                    onPressed: onCall,
                    icon: const Icon(Icons.call_rounded, size: 18, color: AppTheme.primary),
                    label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFF1F5F9)),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.text, padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)))
                    ),
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF25D366)),
                    label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

class _SmallDetail extends StatelessWidget {
  const _SmallDetail({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.text)),
        ],
      ),
    );
  }
}

// 2. Status Card (Flat Design)
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.statuses, required this.currentStatusId, required this.selectedStatus, required this.updating, required this.onChanged, required this.onUpdate});
  final List<Map<String, dynamic>> statuses;
  final int? currentStatusId;
  final int? selectedStatus;
  final bool updating;
  final ValueChanged<int?> onChanged;
  final VoidCallback onUpdate;

  Color? _parseStatusColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return _FlatToolCard(
      icon: Icons.fact_check_rounded,
      iconColor: AppTheme.success,
      title: 'Update Status',
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            value: selectedStatus ?? currentStatusId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded, color: AppTheme.muted),
            decoration: InputDecoration(
              filled: true, fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            selectedItemBuilder: (context) => statuses.map((s) => _StatusDropdownLabel(name: s['name'].toString(), color: _parseStatusColor(s['color']?.toString()))).toList(),
            items: statuses.map((s) => DropdownMenuItem<int>(
              value: int.parse(s['id'].toString()),
              child: _StatusDropdownLabel(name: s['name'].toString(), color: _parseStatusColor(s['color']?.toString())),
            )).toList(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: updating ? null : onUpdate,
              child: updating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('Save Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Courier Card (Flat Design)
class _CourierCard extends StatelessWidget {
  const _CourierCard({
    required this.couriers, required this.shipments, required this.selectedCourier, required this.pathaoCities,
    required this.pathaoZones, required this.pathaoAreas, required this.selectedCityId, required this.selectedZoneId,
    required this.selectedAreaId, required this.loadingCities, required this.loadingZones, required this.loadingAreas,
    required this.locationId, required this.locationName, required this.sending, required this.onCourierChanged,
    required this.onCityChanged, required this.onZoneChanged, required this.onAreaChanged, required this.onSend,
  });
  // Props matching original exactly[cite: 2]
  final List<Map<String, dynamic>> couriers;
  final List<Map<String, dynamic>> shipments;
  final String selectedCourier;
  final List<Map<String, dynamic>> pathaoCities;
  final List<Map<String, dynamic>> pathaoZones;
  final List<Map<String, dynamic>> pathaoAreas;
  final int? selectedCityId;
  final int? selectedZoneId;
  final int? selectedAreaId;
  final bool loadingCities;
  final bool loadingZones;
  final bool loadingAreas;
  final int? Function(Map<String, dynamic>) locationId;
  final String Function(Map<String, dynamic>) locationName;
  final bool sending;
  final ValueChanged<String> onCourierChanged;
  final ValueChanged<int?> onCityChanged;
  final ValueChanged<int?> onZoneChanged;
  final ValueChanged<int?> onAreaChanged;
  final VoidCallback onSend;

  List<DropdownMenuItem<int>> _locationItems(List<Map<String, dynamic>> items) {
    return items.map((item) {
      final id = locationId(item);
      if (id == null) return null;
      return DropdownMenuItem<int>(value: id, child: Text(locationName(item), style: const TextStyle(fontSize: 14)));
    }).whereType<DropdownMenuItem<int>>().toList();
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppTheme.muted),
      filled: true, fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCouriers = couriers.where((c) => c['is_active'] == true).toList();
    final items = (activeCouriers.isEmpty ? couriers : activeCouriers);

    return _FlatToolCard(
      icon: Icons.local_shipping_rounded,
      iconColor: AppTheme.primary,
      title: 'Courier Booking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty) const Text('No courier configured yet.', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
          if (items.isNotEmpty) 
            DropdownButtonFormField<String>(
              value: items.any((c) => c['key'] == selectedCourier) ? selectedCourier : items.first['key'].toString(), 
              decoration: _inputDeco('Select Courier'),
              items: items.map((c) => DropdownMenuItem<String>(value: c['key'].toString(), child: Text('${c['label']} ${c['is_active'] == true ? '' : '(inactive)'}', style: const TextStyle(fontSize: 14)))).toList(), 
              onChanged: (v) { if (v != null) onCourierChanged(v); }
            ),
          
          if (selectedCourier == 'pathao') ...[
            const SizedBox(height: 12),
            if (loadingCities) const LinearProgressIndicator(minHeight: 2),
            DropdownButtonFormField<int>(
              value: _locationItems(pathaoCities).any((e) => e.value == selectedCityId) ? selectedCityId : null,
              decoration: _inputDeco('Pathao City'),
              items: _locationItems(pathaoCities),
              onChanged: onCityChanged,
            ),
            const SizedBox(height: 10),
            if (loadingZones) const LinearProgressIndicator(minHeight: 2),
            DropdownButtonFormField<int>(
              value: _locationItems(pathaoZones).any((e) => e.value == selectedZoneId) ? selectedZoneId : null,
              decoration: _inputDeco('Pathao Zone'),
              items: _locationItems(pathaoZones),
              onChanged: selectedCityId == null ? null : onZoneChanged,
            ),
            const SizedBox(height: 10),
            if (loadingAreas) const LinearProgressIndicator(minHeight: 2),
            DropdownButtonFormField<int>(
              value: _locationItems(pathaoAreas).any((e) => e.value == selectedAreaId) ? selectedAreaId : null,
              decoration: _inputDeco('Pathao Area'),
              items: _locationItems(pathaoAreas),
              onChanged: selectedZoneId == null ? null : onAreaChanged,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, 
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: sending || items.isEmpty ? null : onSend, 
              child: sending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text('Send to Courier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))
            )
          ),

          if (shipments.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(top: 20, bottom: 8), child: Text('Shipment History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.muted2))),
            for (final s in shipments) 
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                child: Row(
                  children: [
                    Icon(s['status'] == 'sent' ? Icons.check_circle_rounded : Icons.info_rounded, color: s['status'] == 'sent' ? AppTheme.primary : AppTheme.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s['courier']} • ${s['status']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          Text('Tracking: ${s['tracking_code'] ?? s['consignment_id'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]
        ],
      ),
    );
  }
}

// 4. Fraud Checker Card (Flat Design)
class _FraudCard extends StatelessWidget {
  const _FraudCard({required this.fraud, required this.checking, required this.decision, required this.noteCtrl, required this.onCheck, required this.onDecisionChanged, required this.onSaveDecision});
  final Map<String, dynamic>? fraud;
  final bool checking;
  final String decision;
  final TextEditingController noteCtrl;
  final VoidCallback onCheck;
  final ValueChanged<String> onDecisionChanged;
  final VoidCallback onSaveDecision;

  @override
  Widget build(BuildContext context) {
    final suggestion = fraud?['suggestion'] as Map<String, dynamic>?;
    return _FlatToolCard(
      icon: Icons.shield_rounded,
      iconColor: AppTheme.danger,
      title: 'Fraud Checker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _SmallDetail(label: 'Current Decision', value: fraud?['final_decision']?.toString() ?? 'Not decided')),
              if (suggestion != null) Expanded(child: _SmallDetail(label: 'Suggested Risk', value: suggestion['risk_band']?.toString() ?? 'N/A')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, 
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: checking ? null : onCheck, 
              child: checking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Run Auto Check', style: TextStyle(fontWeight: FontWeight.w700))
            )
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: decision, 
            decoration: InputDecoration(
              labelText: 'Manual Decision', labelStyle: const TextStyle(fontSize: 13, color: AppTheme.muted),
              filled: true, fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: const ['APPROVE_COD', 'REQUIRE_OTP', 'HOLD_CALL_VERIFICATION', 'REQUIRE_ADVANCE', 'CANCEL'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(), 
            onChanged: (v) { if (v != null) onDecisionChanged(v); }
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl, maxLines: 2, 
            decoration: InputDecoration(
              hintText: 'Add internal note...', hintStyle: const TextStyle(fontSize: 13, color: AppTheme.muted),
              filled: true, fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            )
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, 
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: onSaveDecision, 
              child: const Text('Save Decision', style: TextStyle(fontWeight: FontWeight.w700))
            )
          ),
        ],
      ),
    );
  }
}

// 5. Invoice Style Items Table
class _OrderItemsTable extends StatelessWidget {
  const _OrderItemsTable({required this.items, required this.total});
  final List<dynamic> items;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36, alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                        child: Text('${item['qty']}x', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.muted)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['product_name']?.toString() ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.text)),
                            const SizedBox(height: 2),
                            Text('৳ ${item['price']} each', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('৳ ${item['subtotal'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                ),
                if (index < items.length - 1) const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
            );
          }),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted2)),
                Text('৳ $total', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primary)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// UTILITY WIDGETS
class _FlatToolCard extends StatelessWidget {
  const _FlatToolCard({required this.icon, required this.iconColor, required this.title, required this.child});
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.text)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
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
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, required this.onCopy});
  final IconData icon;
  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text.isEmpty ? 'N/A' : text, style: const TextStyle(fontSize: 13, color: AppTheme.muted2))),
          if (text.isNotEmpty)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary)),
            )
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color ?? AppTheme.primary, shape: BoxShape.circle));
}

class _StatusDropdownLabel extends StatelessWidget {
  const _StatusDropdownLabel({required this.name, this.color});
  final String name;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusDot(color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
      ],
    );
  }
}