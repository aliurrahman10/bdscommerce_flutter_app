import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'customer_detail_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();
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
    return workspace.storeApi.customers(workspace.activeStoreToken!, search: _search.text);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customer or mobile'),
              onSubmitted: (_) => _refresh(),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                if (items.isEmpty) return const Center(child: Text('No customers found.'));
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final customer = items[i];
                      final name = customer['name']?.toString().isNotEmpty == true ? customer['name'].toString() : 'Customer';
                      final mobile = customer['mobile']?.toString() ?? '';
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: customer))),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              CircleAvatar(backgroundColor: const Color(0xFFEAF0F2), child: Text(name.characters.first.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(mobile, style: const TextStyle(color: AppTheme.muted)),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, runSpacing: 6, children: [
                                    _Chip(text: 'Orders: ${customer['total_orders'] ?? 0}'),
                                    _Chip(text: '৳ ${customer['total_spent'] ?? 0}'),
                                  ]),
                                ]),
                              ),
                              IconButton(
                                tooltip: 'Copy phone',
                                onPressed: mobile.isEmpty ? null : () {
                                  Clipboard.setData(ClipboardData(text: mobile));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone copied.')));
                                },
                                icon: const Icon(Icons.copy, size: 20),
                              ),
                              const Icon(Icons.chevron_right),
                            ]),
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
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
