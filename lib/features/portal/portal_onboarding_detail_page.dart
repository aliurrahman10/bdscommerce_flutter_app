import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';

class PortalOnboardingDetailPage extends StatefulWidget {
  const PortalOnboardingDetailPage({super.key, required this.id});
  final int id;
  @override
  State<PortalOnboardingDetailPage> createState() => _PortalOnboardingDetailPageState();
}

class _PortalOnboardingDetailPageState extends State<PortalOnboardingDetailPage> {
  late Future<Map<String, dynamic>> _future;
  final Map<String, TextEditingController> _c = {};
  bool _saving = false;
  String _fileType = 'logo';

  @override
  void initState() { super.initState(); _future = _load(); }
  @override
  void dispose() { for (final c in _c.values) c.dispose(); super.dispose(); }
  TextEditingController ctrl(String key, [String value = '']) => _c.putIfAbsent(key, () => TextEditingController(text: value));
  Future<Map<String, dynamic>> _load() => context.read<WorkspaceController>().portalApi.onboardingDetail(context.read<WorkspaceController>().portalToken!, widget.id);
  Future<void> _refresh() async { final next = _load(); setState(() { _future = next; }); await next; }

  void _sync(Map<String, dynamic> o) {
    for (final key in ['business_name','business_phone','business_email','brand_colors','facebook_page','google_analytics','facebook_pixel','payment_notes','courier_notes','product_notes','content_notes','client_note']) {
      ctrl(key, o[key]?.toString() ?? '').text = o[key]?.toString() ?? '';
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.portalApi.updateOnboarding(workspace.portalToken!, widget.id, {for (final e in _c.entries) e.key: e.value.text.trim()});
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _uploadImages() async {
    final images = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.portalApi.uploadOnboardingFiles(workspace.portalToken!, widget.id, _fileType, images.map((e) => e.path).toList());
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files uploaded.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.portalApi.submitOnboarding(workspace.portalToken!, widget.id);
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for review.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding Detail')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final o = snapshot.data?['onboarding'] as Map<String, dynamic>? ?? {};
          if (_c.isEmpty) _sync(o);
          final files = (o['files'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return Stack(children: [
            ListView(padding: const EdgeInsets.all(16), children: [
              Text(o['service_name']?.toString() ?? 'Service onboarding', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text('${o['domain'] ?? ''} • ${o['status'] ?? 'pending'} • ${o['completion_percent'] ?? 0}%'),
              const SizedBox(height: 16),
              _field('business_name', 'Business name'), _field('business_phone', 'Business phone'), _field('business_email', 'Business email'), _field('brand_colors', 'Brand colors'),
              _field('facebook_page', 'Facebook page'), _field('google_analytics', 'Google Analytics'), _field('facebook_pixel', 'Facebook Pixel'),
              _field('payment_notes', 'Payment notes', lines: 3), _field('courier_notes', 'Courier notes', lines: 3), _field('product_notes', 'Product/category notes', lines: 3), _field('content_notes', 'Content notes', lines: 3), _field('client_note', 'Additional note', lines: 3),
              FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save Information')),
              const SizedBox(height: 18),
              const Text('Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(value: _fileType, decoration: const InputDecoration(labelText: 'File type'), items: const [DropdownMenuItem(value:'logo', child: Text('Logo')), DropdownMenuItem(value:'banner', child: Text('Banner')), DropdownMenuItem(value:'product', child: Text('Product')), DropdownMenuItem(value:'content', child: Text('Content')), DropdownMenuItem(value:'payment', child: Text('Payment/Courier')), DropdownMenuItem(value:'general', child: Text('General'))], onChanged: (v) => setState(() => _fileType = v ?? _fileType)),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _saving ? null : _uploadImages, icon: const Icon(Icons.upload_file), label: const Text('Upload Images/Screenshots')),
              for (final f in files) ListTile(leading: const Icon(Icons.attach_file), title: Text(f['name']?.toString() ?? 'File'), subtitle: Text(f['type']?.toString() ?? ''), onTap: () { final url = f['url']?.toString() ?? ''; if (url.isNotEmpty) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _saving ? null : _submit, icon: const Icon(Icons.check_circle_outline), label: const Text('Submit for Review')),
            ]),
            if (_saving) Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
          ]);
        },
      ),
    );
  }

  Widget _field(String key, String label, {int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: ctrl(key), minLines: lines, maxLines: lines == 1 ? 1 : 5, decoration: InputDecoration(labelText: label)));
}
