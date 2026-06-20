import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/app_theme_controller.dart';
import 'locked_feature.dart';

class PremiumHeroCard extends StatelessWidget {
  const PremiumHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.icon = Icons.auto_awesome,
    this.action,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final preset = context.watch<AppThemeController>().selectedPreset;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: preset.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppTheme.glowShadow(preset.key),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -22,
            child: Icon(icon, color: Colors.white.withOpacity(0.09), size: 120),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  if (badge != null && badge!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.80), height: 1.48, fontSize: 14.2, fontWeight: FontWeight.w500)),
              if (action != null) ...[
                const SizedBox(height: 15),
                action!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumMetricCard extends StatelessWidget {
  const PremiumMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.caption,
  });

  final String title;
  final Object value;
  final IconData icon;
  final Gradient gradient;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              const Icon(Icons.trending_up_rounded, color: AppTheme.muted2, size: 17),
            ],
          ),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted2, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class PremiumActionTile extends StatelessWidget {
  const PremiumActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.onTap,
    this.trailing,
    this.badge,
    this.locked = false,
    this.requiredPackage = 'a higher plan',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? badge;
  final bool locked;
  final String requiredPackage;

  @override
  Widget build(BuildContext context) {
    final base = Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: locked ? const Color(0xFFFECACA) : AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: locked ? () => LockedFeatureNotice.show(context, title: title, requiredPackage: requiredPackage) : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: locked ? const LinearGradient(colors: [Color(0xFFF87171), Color(0xFFDC2626)]) : gradient, borderRadius: BorderRadius.circular(16)),
                  child: Icon(locked ? Icons.lock_rounded : icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: locked ? const Color(0xFF7F1D1D) : AppTheme.text, fontSize: 14.5))),
                          if (locked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFFECACA))),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.lock_rounded, size: 11, color: Color(0xFFDC2626)),
                                const SizedBox(width: 3),
                                Text(requiredPackage, style: const TextStyle(fontSize: 10, color: Color(0xFF991B1B), fontWeight: FontWeight.w900)),
                              ]),
                            )
                          else if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
                              child: Text(badge!, style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locked ? '$subtitle\nAvailable in $requiredPackage plan. Tap to see upgrade note.' : subtitle,
                        maxLines: locked ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: locked ? const Color(0xFF991B1B).withOpacity(0.72) : AppTheme.muted, fontSize: 12, height: 1.34, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(locked ? Icons.arrow_upward_rounded : Icons.chevron_right_rounded, color: locked ? const Color(0xFFDC2626) : AppTheme.muted2),
              ],
            ),
          ),
        ),
      ),
    );

    return LockedFeatureSurface(
      locked: locked,
      title: title,
      requiredPackage: requiredPackage,
      borderRadius: 21,
      child: base,
    );
  }
}
class PremiumSectionTitle extends StatelessWidget {
  const PremiumSectionTitle({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 3, 2, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w500, height: 1.35)),
          ],
        ],
      ),
    );
  }
}
