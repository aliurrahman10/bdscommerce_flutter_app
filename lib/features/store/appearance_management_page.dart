import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import 'sliders_page.dart';
import 'theme_basic_page.dart';
import '../../shared/widgets/locked_feature.dart';

class AppearanceManagementPage extends StatelessWidget {
  const AppearanceManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.appearanceSummary(workspace.activeStoreToken!),
        builder: (context, snapshot) {
          final summary = snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          final locked = features['theme_customization'] == false;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theme & Website Sliders', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Sliders: ${summary['sliders'] ?? 0} • Active: ${summary['active_sliders'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (locked)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Theme customization locked', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Ei feature current subscription plan e enabled na.'),
                  ),
                ),
              _Tile(icon: Icons.palette_outlined, title: 'Basic Theme Settings', subtitle: 'Colors, site identity and basic theme toggles', page: const ThemeBasicPage(), locked: locked),
              _Tile(icon: Icons.slideshow_outlined, title: 'Website Sliders', subtitle: 'Add, edit, image upload and active/inactive sliders', page: const SlidersPage(), locked: locked),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.page, this.locked = false, this.requiredPackage = 'Scale'});
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
