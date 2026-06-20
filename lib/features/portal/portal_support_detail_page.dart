import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/workspace_controller.dart';

class PortalSupportDetailPage extends StatefulWidget {
  const PortalSupportDetailPage({super.key, required this.ticketId});
  final int ticketId;

  @override
  State<PortalSupportDetailPage> createState() => _PortalSupportDetailPageState();
}

class _PortalSupportDetailPageState extends State<PortalSupportDetailPage> {
  late Future<Map<String, dynamic>> _future;
  final _reply = TextEditingController();
  bool _sending = false;
  final List<XFile> _files = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.supportTicket(workspace.portalToken!, widget.ticketId);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
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

  Future<void> _openAttachment(String url) async {
    if (url.trim().isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _sendReply() async {
    if (_reply.text.trim().isEmpty && _files.isEmpty) return;
    setState(() => _sending = true);
    try {
      final workspace = context.read<WorkspaceController>();
      if (_files.isEmpty) {
        await workspace.portalApi.replySupportTicket(workspace.portalToken!, widget.ticketId, _reply.text.trim());
      } else {
        await workspace.portalApi.replySupportTicketMultipart(workspace.portalToken!, widget.ticketId, _reply.text.trim().isEmpty ? 'Attachment' : _reply.text.trim(), _files.map((f) => f.path).toList());
      }
      _reply.clear();
      _files.clear();
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }


  Future<void> _setTicketStatus(String status) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'resolved' ? 'Mark as resolved?' : 'Close ticket?'),
        content: Text(status == 'resolved'
            ? 'This will mark the ticket as resolved. You can open a new ticket if you need help later.'
            : 'This will close the ticket. You can open a new ticket if you need help later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(status == 'resolved' ? 'Resolved' : 'Close')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _sending = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.portalApi.updateSupportTicketStatus(workspace.portalToken!, widget.ticketId, status);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'resolved' ? 'Ticket marked as resolved.' : 'Ticket closed.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ticket #${widget.ticketId}'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final ticket = snapshot.data?['ticket'] as Map<String, dynamic>? ?? {};
          final messages = snapshot.data?['messages'] as List<dynamic>? ?? [];
          final closed = ['resolved', 'closed'].contains(ticket['status']?.toString());
          return Column(children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ticket['subject']?.toString() ?? 'Support ticket', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      Chip(label: Text(ticket['status']?.toString() ?? 'open')),
                      Chip(label: Text(ticket['priority']?.toString() ?? 'normal')),
                      Chip(label: Text(ticket['type']?.toString() ?? 'general')),
                    ]),
                    if ((ticket['domain'] ?? '').toString().isNotEmpty) Text('Service: ${ticket['domain']}'),
                    if (!closed) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                          onPressed: _sending ? null : () => _setTicketStatus('resolved'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark resolved'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _sending ? null : () => _setTicketStatus('closed'),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Close ticket'),
                        ),
                      ]),
                    ],
                  ]))),
                  ...messages.map((raw) => _MessageBubble(message: raw as Map<String, dynamic>, onOpenAttachment: _openAttachment)),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
            if (!closed) SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_files.isNotEmpty) SizedBox(
                  height: 42,
                  child: ListView(scrollDirection: Axis.horizontal, children: _files.map((file) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(label: Text(file.name), onDeleted: () => setState(() => _files.remove(file))),
                  )).toList()),
                ),
                Row(children: [
                  IconButton(onPressed: _pickFiles, icon: const Icon(Icons.attach_file)),
                  Expanded(child: TextField(controller: _reply, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Write a reply...'))),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _sending ? null : _sendReply, child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
                ]),
              ]),
            )),
          ]);
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onOpenAttachment});
  final Map<String, dynamic> message;
  final Future<void> Function(String url) onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final client = (message['author_type'] ?? '').toString() == 'client';
    return Align(
      alignment: client ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: client ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(client ? 'You' : 'Support Team', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(message['message']?.toString() ?? ''),
          if ((message['attachments'] as List<dynamic>? ?? []).isNotEmpty) ...[
            const SizedBox(height: 8),
            ...(message['attachments'] as List<dynamic>).whereType<Map<String, dynamic>>().map((file) => ActionChip(
              avatar: const Icon(Icons.attach_file, size: 16),
              label: Text(file['name']?.toString() ?? 'Attachment'),
              onPressed: () => onOpenAttachment(file['url']?.toString() ?? ''),
            )),
          ],
          const SizedBox(height: 4),
          Text(message['created_at']?.toString() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }
}
