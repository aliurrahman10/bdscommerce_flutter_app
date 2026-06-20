import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class ContentPagesPage extends StatelessWidget {
  const ContentPagesPage({super.key});
  @override
  Widget build(BuildContext context) => const _ContentEntryPage(isPost: false, title: 'Website Pages');
}

class BlogPostsPage extends StatelessWidget {
  const BlogPostsPage({super.key});
  @override
  Widget build(BuildContext context) => const _ContentEntryPage(isPost: true, title: 'Blog / News');
}

class _ContentEntryPage extends StatefulWidget {
  const _ContentEntryPage({required this.isPost, required this.title});
  final bool isPost;
  final String title;

  @override
  State<_ContentEntryPage> createState() => _ContentEntryPageState();
}

class _ContentEntryPageState extends State<_ContentEntryPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    final token = workspace.activeStoreToken!;
    return widget.isPost ? workspace.storeApi.contentPosts(token) : workspace.storeApi.contentPages(token);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _entryDialog([Map<String, dynamic>? row]) async {
    final title = TextEditingController(text: row?['title']?.toString() ?? '');
    final slug = TextEditingController(text: row?['slug']?.toString() ?? '');
    final excerpt = TextEditingController(text: row?['excerpt']?.toString() ?? '');
    final content = TextEditingController(text: row?['content']?.toString() ?? '');
    final image = TextEditingController(text: row?['featured_image']?.toString() ?? '');
    final metaTitle = TextEditingController(text: row?['meta_title']?.toString() ?? '');
    final metaDescription = TextEditingController(text: row?['meta_description']?.toString() ?? '');
    final metaKeywords = TextEditingController(text: row?['meta_keywords']?.toString() ?? '');
    String status = row?['status']?.toString() == 'published' ? 'published' : 'draft';
    bool isHome = row?['is_home'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Add ${widget.isPost ? 'Post' : 'Page'}' : 'Edit ${widget.isPost ? 'Post' : 'Page'}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
              const SizedBox(height: 8),
              if (widget.isPost) TextField(controller: excerpt, decoration: const InputDecoration(labelText: 'Excerpt'), maxLines: 2),
              if (widget.isPost) const SizedBox(height: 8),
              TextField(controller: content, decoration: const InputDecoration(labelText: 'Content / HTML'), minLines: 3, maxLines: 7),
              const SizedBox(height: 8),
              TextField(controller: image, decoration: const InputDecoration(labelText: 'Featured / OG image path or URL')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [DropdownMenuItem(value: 'draft', child: Text('Draft')), DropdownMenuItem(value: 'published', child: Text('Published'))],
                onChanged: (v) => setLocal(() => status = v ?? 'draft'),
              ),
              if (!widget.isPost) CheckboxListTile(value: isHome, onChanged: (v) => setLocal(() => isHome = v ?? false), title: const Text('Mark as homepage'), contentPadding: EdgeInsets.zero),
              const Divider(height: 24),
              Align(alignment: Alignment.centerLeft, child: Text('SEO Basic', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              TextField(controller: metaTitle, decoration: const InputDecoration(labelText: 'Meta title')),
              const SizedBox(height: 8),
              TextField(controller: metaDescription, decoration: const InputDecoration(labelText: 'Meta description'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: metaKeywords, decoration: const InputDecoration(labelText: 'Meta keywords')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final data = <String, dynamic>{
        'title': title.text.trim(),
        'slug': slug.text.trim(),
        'content': content.text,
        'featured_image': image.text.trim(),
        'status': status,
        'meta_title': metaTitle.text.trim(),
        'meta_description': metaDescription.text.trim(),
        'meta_keywords': metaKeywords.text.trim(),
        if (widget.isPost) 'excerpt': excerpt.text.trim(),
        if (!widget.isPost) 'is_home': isHome,
      };
      if (widget.isPost) {
        if (row == null) {
          await workspace.storeApi.createContentPost(token, data);
        } else {
          await workspace.storeApi.updateContentPost(token, int.parse(row['id'].toString()), data);
        }
      } else {
        if (row == null) {
          await workspace.storeApi.createContentPage(token, data);
        } else {
          await workspace.storeApi.updateContentPage(token, int.parse(row['id'].toString()), data);
        }
      }
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final id = int.parse(row['id'].toString());
      if (widget.isPost) {
        await workspace.storeApi.deleteContentPost(token, id);
      } else {
        await workspace.storeApi.deleteContentPage(token, id);
      }
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _entryDialog(), icon: const Icon(Icons.add), label: Text(widget.isPost ? 'Post' : 'Page')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final rows = ((snapshot.data?['data'] ?? []) as List<dynamic>).cast<Map<String, dynamic>>();
          if (rows.isEmpty) return Center(child: Text('No ${widget.isPost ? 'post' : 'page'} found.'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              final published = row['status'] == 'published';
              return Card(
                child: ListTile(
                  leading: Icon(widget.isPost ? Icons.article_outlined : Icons.description_outlined, color: AppTheme.primary),
                  title: Text(row['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${row['slug'] ?? ''}\n${published ? 'Published' : 'Draft'}${row['is_home'] == true ? ' • Home' : ''}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _entryDialog(row);
                      if (v == 'delete') _delete(row);
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                  ),
                  onTap: () => _entryDialog(row),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
