import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'slider_form_page.dart';

class SlidersPage extends StatefulWidget {
  const SlidersPage({super.key});

  @override
  State<SlidersPage> createState() => _SlidersPageState();
}

class _SlidersPageState extends State<SlidersPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.sliders(workspace.activeStoreToken!);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? slider]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SliderFormPage(slider: slider)));
    _refresh();
  }

  Future<void> _delete(Map<String, dynamic> slider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete slider?'),
        content: Text('Delete ${slider['name'] ?? 'this slider'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.deleteSlider(workspace.activeStoreToken!, int.parse(slider['id'].toString()));
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slider deleted.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> slider, bool active) async {
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updateSlider(workspace.activeStoreToken!, int.parse(slider['id'].toString()), {'status': active ? 'active' : 'inactive'});
      _refresh();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Website Sliders'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Slider')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final sliders = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          if (sliders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.slideshow_outlined, size: 56, color: AppTheme.primary),
                    const SizedBox(height: 12),
                    const Text('No slider found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text('Website home page slider mobile app thekei manage kora jabe.'),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Add Slider')),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
              itemCount: sliders.length,
              itemBuilder: (context, index) {
                final slider = sliders[index];
                final active = slider['status']?.toString() == 'active';
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((slider['image_url'] ?? '').toString().isNotEmpty)
                        AspectRatio(
                          aspectRatio: 16 / 7,
                          child: Image.network(slider['image_url'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
                        ),
                      ListTile(
                        title: Text(slider['name']?.toString() ?? 'Slider', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${slider['title'] ?? ''}\nStatus: ${slider['status']}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _openForm(slider);
                            if (value == 'delete') _delete(slider);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => _openForm(slider),
                      ),
                      SwitchListTile(value: active, onChanged: (value) => _toggleStatus(slider, value), title: const Text('Active')),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
