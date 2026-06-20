import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/state/workspace_controller.dart';

class PortalSupportCreatePage extends StatefulWidget {
  const PortalSupportCreatePage({super.key, this.service});
  final Map<String, dynamic>? service;

  @override
  State<PortalSupportCreatePage> createState() => _PortalSupportCreatePageState();
}

class _PortalSupportCreatePageState extends State<PortalSupportCreatePage> {
  late Future<Map<String, dynamic>> _servicesFuture;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _type = 'general';
  String _priority = 'normal';
  int? _serviceId;
  bool _submitting = false;
  final List<XFile> _files = [];

  @override
  void initState() {
    super.initState();
    _serviceId = int.tryParse(widget.service?['id']?.toString() ?? '');
    _servicesFuture = _loadServices();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadServices() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.services(workspace.portalToken!);
  }


  Future<void> _pickFiles() async {
    final picker = ImagePicker();
    final result = await picker.pickMultiImage(imageQuality: 85);
    if (result.isEmpty) return;
    setState(() {
      _files
        ..clear()
        ..addAll(result.where((f) => f.path.isNotEmpty).take(5));
    });
  }

  Future<void> _submit(List<dynamic> services) async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject and message are required.')));
      return;
    }
    Map<String, dynamic>? selected;
    for (final raw in services) {
      if (raw is Map<String, dynamic> && int.tryParse(raw['id'].toString()) == _serviceId) {
        selected = raw;
        break;
      }
    }
    setState(() => _submitting = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final payload = {
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
        'type': _type,
        'priority': _priority,
        if (_serviceId != null) 'portal_order_id': _serviceId,
        if (selected != null) 'domain': selected['domain'] ?? selected['tenant_slug'],
      };
      if (_files.isEmpty) {
        await workspace.portalApi.createSupportTicket(workspace.portalToken!, payload);
      } else {
        await workspace.portalApi.createSupportTicketMultipart(workspace.portalToken!, payload, _files.map((f) => f.path).toList());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support ticket created.')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Support Ticket')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final services = snapshot.data?['data'] as List<dynamic>? ?? [];
          return ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<int>(
              value: services.any((e) => e is Map && int.tryParse(e['id'].toString()) == _serviceId) ? _serviceId : null,
              decoration: const InputDecoration(labelText: 'Related service'),
              items: services.whereType<Map<String, dynamic>>().map((s) {
                final id = int.parse(s['id'].toString());
                final plan = s['plan'] as Map<String, dynamic>?;
                return DropdownMenuItem<int>(value: id, child: Text('${s['domain'] ?? s['tenant_slug'] ?? 'Service'} • ${plan?['name'] ?? 'Plan'}'));
              }).toList(),
              onChanged: (value) => setState(() => _serviceId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'billing', child: Text('Billing')),
                DropdownMenuItem(value: 'renewal', child: Text('Renewal')),
                DropdownMenuItem(value: 'technical', child: Text('Technical issue')),
                DropdownMenuItem(value: 'domain', child: Text('Domain issue')),
                DropdownMenuItem(value: 'store', child: Text('Store issue')),
                DropdownMenuItem(value: 'plan_upgrade', child: Text('Plan upgrade')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'general'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (value) => setState(() => _priority = value ?? 'normal'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 12),
            TextField(controller: _message, maxLines: 6, decoration: const InputDecoration(labelText: 'Message / issue details')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _pickFiles, icon: const Icon(Icons.attach_file), label: Text(_files.isEmpty ? 'Attach files' : '${_files.length} file(s) selected')),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._files.map((file) => ListTile(dense: true, leading: const Icon(Icons.insert_drive_file_outlined), title: Text(file.name), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _files.remove(file))))),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : () => _submit(services),
              icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: Text(_submitting ? 'Submitting...' : 'Submit Ticket'),
            ),
          ]);
        },
      ),
    );
  }
}
