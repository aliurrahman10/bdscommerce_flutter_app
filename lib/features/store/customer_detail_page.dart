import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'order_detail_page.dart';

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.customer});
  final Map<String, dynamic> customer;

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceController>();
    final mobile = customer['mobile']?.toString() ?? '';
    final name = customer['name']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.customerDetail(workspace.activeStoreToken!, mobile: mobile, name: name),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final data = snapshot.data ?? {};
          final c = data['customer'] as Map<String, dynamic>? ?? customer;
          final orders = (data['orders'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const CircleAvatar(radius: 26, child: Icon(Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(c['name']?.toString().isNotEmpty == true ? c['name'].toString() : 'Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                    ]),
                    const SizedBox(height: 14),
                    _Info(icon: Icons.phone_outlined, text: c['mobile']?.toString() ?? '', copy: true),
                    _Info(icon: Icons.location_on_outlined, text: c['address']?.toString() ?? '', copy: true),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _Metric(title: 'Orders', value: c['total_orders'] ?? orders.length, icon: Icons.shopping_bag_outlined),
                  _Metric(title: 'Spent', value: '৳ ${c['total_spent'] ?? 0}', icon: Icons.payments_outlined),
                  _Metric(title: 'Paid', value: c['paid_orders'] ?? 0, icon: Icons.verified_outlined),
                  _Metric(title: 'Unpaid', value: c['unpaid_orders'] ?? 0, icon: Icons.pending_actions_outlined),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Order History', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              if (orders.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No order history found.')))),
              for (final order in orders)
                Card(
                  child: ListTile(
                    title: Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${order['created_at'] ?? ''}\n${order['payment_status'] ?? ''} • ${order['order_status']?['name'] ?? order['status'] ?? ''}'),
                    isThreeLine: true,
                    trailing: Text('৳ ${order['total'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: int.parse(order['id'].toString())))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text, this.copy = false});
  final IconData icon;
  final String text;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
        if (copy) IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.'))); }),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});
  final String title;
  final Object value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}
