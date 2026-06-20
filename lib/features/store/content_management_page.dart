import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'content_pages_page.dart';
import 'menus_page.dart';
import '../../shared/widgets/locked_feature.dart';

class ContentManagementPage extends StatefulWidget {
  const ContentManagementPage({super.key});

  @override
  State<ContentManagementPage> createState() => _ContentManagementPageState();
}

class _ContentManagementPageState extends State<ContentManagementPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.storeApi.contentSummary(workspace.activeStoreToken!);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content & SEO'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          final pageLocked = features['page_builder'] == false;
          final menuLocked = features['menu_builder'] == false;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Website Content', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Pages: ${summary['pages'] ?? 0} • Posts: ${summary['posts'] ?? 0} • Menus: ${summary['menus'] ?? 0}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 14),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Dependency check: Pages, Blog and SEO follow Page Builder package access. Menu management follows Menu Builder package access. Write access also requires Manage Content permission.'),
              ),
            ),
            _ContentTile(icon: Icons.description_outlined, title: 'Website Pages', subtitle: 'Create, edit, publish and SEO fields', page: const ContentPagesPage(), locked: pageLocked),
            _ContentTile(icon: Icons.article_outlined, title: 'Blog / News', subtitle: 'Create, edit, publish and SEO fields', page: const BlogPostsPage(), locked: pageLocked),
            _ContentTile(icon: Icons.menu_open_outlined, title: 'Menu Management', subtitle: 'Menus and menu links', page: const MenusPage(), locked: menuLocked),
          ]);
        },
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  // ignore: unused_element_parameter
  const _ContentTile({required this.icon, required this.title, required this.subtitle, required this.page, required this.locked, this.requiredPackage = 'Scale'});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  final bool locked;
  final String requiredPackage;

  @override
  Widget build(BuildContext context) {
    return LockedFeatureTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      locked: locked,
      requiredPackage: requiredPackage,
      onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
    );
  }
}
