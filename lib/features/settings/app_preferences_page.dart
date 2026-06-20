import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_language.dart';
import '../../core/config/app_theme.dart';
import '../../core/state/app_theme_controller.dart';
import '../../shared/widgets/premium_widgets.dart';

class AppPreferencesPage extends StatelessWidget {
  const AppPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppThemeController>();
    final t = controller.t;
    return Scaffold(
      appBar: AppBar(title: Text(t('App Settings', 'অ্যাপ সেটিংস'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PremiumSectionTitle(
            title: t('Language', 'ভাষা'),
            subtitle: t('Default language is English. You can switch to Bangla anytime.', 'Default language English. প্রয়োজন হলে Bangla language select করুন।'),
          ),
          ...AppLanguage.values.map((language) {
            final selected = language == controller.language;
            return _SettingsTile(
              icon: Icons.translate_rounded,
              selected: selected,
              color: controller.selectedPreset.primary,
              title: language.labelEn,
              subtitle: language.labelBn,
              onTap: () => controller.setLanguage(language),
            );
          }),
          const SizedBox(height: 14),
          PremiumSectionTitle(
            title: t('Premium Theme', 'Premium Theme'),
            subtitle: t('Choose a premium color style. The selected theme will be used across the app.', 'Premium color style বেছে নিন। Theme পুরো app-এ apply হবে।'),
          ),
          ...AppTheme.presets.map((preset) {
            final selected = preset.key == controller.selectedThemeKey;
            return _SettingsTile(
              icon: Icons.palette_rounded,
              selected: selected,
              color: preset.primary,
              title: controller.isBangla ? preset.nameBn : preset.name,
              subtitle: controller.isBangla ? preset.name : preset.nameBn,
              onTap: () => controller.setTheme(preset.key),
              gradient: preset.heroGradient,
            );
          }),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.selected, required this.color, required this.title, required this.subtitle, required this.onTap, this.gradient});
  final IconData icon;
  final bool selected;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color.withOpacity(0.55) : AppTheme.border, width: selected ? 1.35 : 1),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(gradient: gradient, color: gradient == null ? color.withOpacity(0.12) : null, borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, color: gradient == null ? color : Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 11.8, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? color : AppTheme.muted2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
