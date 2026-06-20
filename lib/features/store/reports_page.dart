import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'order_detail_page.dart';
import 'product_detail_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.reportsAdvanced(workspace.activeStoreToken!),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final data = snapshot.data ?? {};
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final statuses = (data['status_breakdown'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final lowStock = (data['low_stock_products'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final latestOrders = (data['latest_orders'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Sales Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.45,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _RangeCard(title: 'Today', data: summary['today'] as Map<String, dynamic>? ?? {}),
                  _RangeCard(title: 'Last 7 days', data: summary['last_7_days'] as Map<String, dynamic>? ?? {}),
                  _RangeCard(title: 'Last 30 days', data: summary['last_30_days'] as Map<String, dynamic>? ?? {}),
                  _RangeCard(title: 'All time', data: summary['all_time'] as Map<String, dynamic>? ?? {}),
                ],
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _MiniMetric(title: 'Products', value: summary['products'] ?? 0, icon: Icons.inventory_2_outlined),
                  _MiniMetric(title: 'Categories', value: summary['categories'] ?? 0, icon: Icons.category_outlined),
                  _MiniMetric(title: 'Customers', value: summary['customers'] ?? 0, icon: Icons.people_alt_outlined),
                  _MiniMetric(title: 'Low stock', value: summary['low_stock_count'] ?? 0, icon: Icons.warning_amber_outlined),
                ],
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Order Status'),
              if (statuses.isEmpty) const _Empty(text: 'No status data found.'),
              for (final status in statuses)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.circle, color: AppTheme.primary, size: 14),
                    title: Text(status['name']?.toString() ?? 'Status', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('Sales: ৳ ${status['sales'] ?? 0}'),
                    trailing: Text('${status['total'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Low Stock Products'),
              if (lowStock.isEmpty) const _Empty(text: 'No low stock product found.'),
              for (final product in lowStock)
                Card(
                  child: ListTile(
                    leading: _ProductImage(url: product['thumbnail_url']?.toString()),
                    title: Text(product['name']?.toString() ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('SKU: ${product['sku'] ?? '-'}'),
                    trailing: Text('Stock: ${product['stock_qty'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(productId: int.parse(product['id'].toString())))),
                  ),
                ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Latest Orders'),
              if (latestOrders.isEmpty) const _Empty(text: 'No order found.'),
              for (final order in latestOrders)
                Card(
                  child: ListTile(
                    title: Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${order['customer_name'] ?? ''}\n${order['payment_status'] ?? ''} • ${order['order_status']?['name'] ?? order['status'] ?? ''}'),
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

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.title, required this.data});
  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('৳ ${data['sales'] ?? 0}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('${data['orders'] ?? 0} orders • ${data['paid'] ?? 0} paid', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.title, required this.value, required this.icon});
  final String title;
  final Object value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
            Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ])),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)));
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        color: const Color(0xFFEAF0F2),
        child: url == null || url!.isEmpty ? const Icon(Icons.inventory_2_outlined, color: AppTheme.primary) : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Center(child: Text(text, style: const TextStyle(color: AppTheme.muted)))));
}
