import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
    ]);
    return {'orderResponse': results[0], 'statusesResponse': results[1], 'toolsResponse': results[2]};
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
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'trash') _moveOrderToTrash();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'trash', child: Text('Move to Trash'))],
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CustomerCard(order: order, onCopy: _copy),
              const SizedBox(height: 12),
              _StatusCard(statuses: statuses, currentStatusId: currentStatusId, selectedStatus: _selectedStatus, updating: _updating, onChanged: (v) => _selectedStatus = v, onUpdate: _updateStatus),
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
              const SizedBox(height: 18),
              const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...items.map((raw) {
                final item = raw as Map<String, dynamic>;
                return Card(child: ListTile(title: Text(item['product_name']?.toString() ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Qty: ${item['qty']} • Price: ${item['price']}'), trailing: Text('৳ ${item['subtotal'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900))));
              }),
            ],
          );
        },
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order, required this.onCopy});
  final Map<String, dynamic> order;
  final Future<void> Function(String label, Object? value) onCopy;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(order['customer_name']?.toString() ?? 'Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.phone_outlined, text: order['mobile']?.toString() ?? '', onCopy: () => onCopy('Phone', order['mobile'])),
        _InfoRow(icon: Icons.location_on_outlined, text: order['address']?.toString() ?? '', onCopy: () => onCopy('Address', order['address'])),
        const Divider(height: 24),
        Row(children: [Expanded(child: _MiniMetric(label: 'Total', value: '৳ ${order['total'] ?? 0}')), Expanded(child: _MiniMetric(label: 'Payment', value: order['payment_status']?.toString() ?? 'unpaid'))]),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _MiniMetric(label: 'Method', value: order['payment_method']?.toString() ?? 'N/A')), Expanded(child: _MiniMetric(label: 'Channel', value: order['channel']?.toString() ?? 'N/A'))]),
      ])));
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.statuses, required this.currentStatusId, required this.selectedStatus, required this.updating, required this.onChanged, required this.onUpdate});
  final List<Map<String, dynamic>> statuses;
  final int? currentStatusId;
  final int? selectedStatus;
  final bool updating;
  final ValueChanged<int?> onChanged;
  final VoidCallback onUpdate;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(value: selectedStatus ?? currentStatusId, decoration: const InputDecoration(labelText: 'Order status'), items: statuses.map((s) => DropdownMenuItem<int>(value: int.parse(s['id'].toString()), child: Text(s['name'].toString()))).toList(), onChanged: onChanged),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: updating ? null : onUpdate, icon: updating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.update), label: Text(updating ? 'Updating...' : 'Update Status'))),
      ])));
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({
    required this.couriers,
    required this.shipments,
    required this.selectedCourier,
    required this.pathaoCities,
    required this.pathaoZones,
    required this.pathaoAreas,
    required this.selectedCityId,
    required this.selectedZoneId,
    required this.selectedAreaId,
    required this.loadingCities,
    required this.loadingZones,
    required this.loadingAreas,
    required this.locationId,
    required this.locationName,
    required this.sending,
    required this.onCourierChanged,
    required this.onCityChanged,
    required this.onZoneChanged,
    required this.onAreaChanged,
    required this.onSend,
  });
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
      return DropdownMenuItem<int>(value: id, child: Text(locationName(item)));
    }).whereType<DropdownMenuItem<int>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeCouriers = couriers.where((c) => c['is_active'] == true).toList();
    final items = (activeCouriers.isEmpty ? couriers : activeCouriers);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Courier Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      if (items.isEmpty) const Text('No courier configured yet. Add credentials from Courier Settings.'),
      if (items.isNotEmpty) DropdownButtonFormField<String>(value: items.any((c) => c['key'] == selectedCourier) ? selectedCourier : items.first['key'].toString(), decoration: const InputDecoration(labelText: 'Courier'), items: items.map((c) => DropdownMenuItem<String>(value: c['key'].toString(), child: Text('${c['label']} ${c['is_active'] == true ? '' : '(inactive)'}'))).toList(), onChanged: (v) { if (v != null) onCourierChanged(v); }),
      if (selectedCourier == 'pathao') ...[
        const SizedBox(height: 10),
        if (loadingCities) const LinearProgressIndicator(),
        DropdownButtonFormField<int>(
          value: _locationItems(pathaoCities).any((e) => e.value == selectedCityId) ? selectedCityId : null,
          decoration: const InputDecoration(labelText: 'Pathao City'),
          items: _locationItems(pathaoCities),
          onChanged: onCityChanged,
        ),
        const SizedBox(height: 10),
        if (loadingZones) const LinearProgressIndicator(),
        DropdownButtonFormField<int>(
          value: _locationItems(pathaoZones).any((e) => e.value == selectedZoneId) ? selectedZoneId : null,
          decoration: const InputDecoration(labelText: 'Pathao Zone'),
          items: _locationItems(pathaoZones),
          onChanged: selectedCityId == null ? null : onZoneChanged,
        ),
        const SizedBox(height: 10),
        if (loadingAreas) const LinearProgressIndicator(),
        DropdownButtonFormField<int>(
          value: _locationItems(pathaoAreas).any((e) => e.value == selectedAreaId) ? selectedAreaId : null,
          decoration: const InputDecoration(labelText: 'Pathao Area'),
          items: _locationItems(pathaoAreas),
          onChanged: selectedZoneId == null ? null : onAreaChanged,
        ),
        const SizedBox(height: 6),
        const Text('City select korle Zone load hobe, Zone select korle Area load hobe.', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
      ],
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: sending || items.isEmpty ? null : onSend, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.local_shipping_outlined), label: Text(sending ? 'Sending...' : 'Send to Courier'))),
      const SizedBox(height: 12),
      const Text('Shipment History', style: TextStyle(fontWeight: FontWeight.w900)),
      if (shipments.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('No shipment yet.')),
      for (final s in shipments) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(s['status'] == 'sent' ? Icons.check_circle : Icons.info_outline, color: s['status'] == 'sent' ? AppTheme.primary : Colors.orange), title: Text('${s['courier']} • ${s['status']}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Tracking: ${s['tracking_code'] ?? s['consignment_id'] ?? 'N/A'}')),
    ])));
  }
}

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
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Fraud Checker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text('Decision: ${fraud?['final_decision'] ?? 'Not decided'}', style: const TextStyle(fontWeight: FontWeight.bold)),
      if (suggestion != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Suggested: ${suggestion['suggested_decision'] ?? 'N/A'} • Risk: ${suggestion['risk_band'] ?? 'N/A'}')),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: checking ? null : onCheck, icon: checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.security_outlined), label: Text(checking ? 'Checking...' : 'Run Fraud Check'))),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: decision, decoration: const InputDecoration(labelText: 'Final decision'), items: const ['APPROVE_COD', 'REQUIRE_OTP', 'HOLD_CALL_VERIFICATION', 'REQUIRE_ADVANCE', 'CANCEL'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) onDecisionChanged(v); }),
      const SizedBox(height: 10),
      TextField(controller: noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Decision note')),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onSaveDecision, icon: const Icon(Icons.save_outlined), label: const Text('Save Fraud Decision'))),
    ])));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, required this.onCopy});
  final IconData icon;
  final String text;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(icon, size: 18, color: AppTheme.primary), const SizedBox(width: 8), Expanded(child: Text(text.isEmpty ? 'N/A' : text)), IconButton(onPressed: text.isEmpty ? null : onCopy, icon: const Icon(Icons.copy, size: 18))]));
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))]));
}
