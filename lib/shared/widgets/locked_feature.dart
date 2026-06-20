import 'package:flutter/material.dart';

String lockedRequiredPackage(Object? value, {String fallback = 'a higher plan'}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

class LockedFeatureNotice {
  static void show(
    BuildContext context, {
    required String title,
    String requiredPackage = 'a higher plan',
    String? message,
  }) {
    final plan = lockedRequiredPackage(requiredPackage);
    final text = message ?? '$title is available in the $plan plan. Please upgrade plan to unlock this feature.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

class LockedFeatureDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String requiredPackage = 'a higher plan',
    String? message,
  }) {
    final plan = lockedRequiredPackage(requiredPackage);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626)),
        title: Text('$title locked'),
        content: Text(message ?? '$title is available in the $plan plan. Please upgrade plan to unlock it.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}

class LockedFeatureSurface extends StatelessWidget {
  const LockedFeatureSurface({
    super.key,
    required this.locked,
    required this.title,
    required this.requiredPackage,
    required this.child,
    this.borderRadius = 18,
    this.onTap,
    this.showPlanChip = true,
  });

  final bool locked;
  final String title;
  final String requiredPackage;
  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool showPlanChip;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    final plan = lockedRequiredPackage(requiredPackage);
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: onTap ?? () => LockedFeatureNotice.show(context, title: title, requiredPackage: plan),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: Colors.white.withOpacity(0.58),
                  border: Border.all(color: const Color(0xFFFECACA).withOpacity(0.85)),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFECACA)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 13, color: Color(0xFFDC2626)),
                if (showPlanChip) ...[
                  const SizedBox(width: 4),
                  Text(
                    plan,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w900),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LockedFeatureTile extends StatelessWidget {
  const LockedFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.onOpen,
    this.requiredPackage = 'a higher plan',
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback onOpen;
  final String requiredPackage;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = lockedRequiredPackage(requiredPackage);
    final tile = Card(
      margin: margin,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: locked ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: Icon(locked ? Icons.lock_rounded : icon, color: locked ? const Color(0xFFDC2626) : theme.colorScheme.primary),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (locked) const Icon(Icons.lock_rounded, size: 18, color: Color(0xFFDC2626)),
          ],
        ),
        subtitle: Text(locked ? '$subtitle\nAvailable in $plan plan' : subtitle),
        isThreeLine: locked,
        trailing: Icon(locked ? Icons.arrow_upward_rounded : Icons.chevron_right_rounded),
        onTap: locked ? () => LockedFeatureNotice.show(context, title: title, requiredPackage: plan) : onOpen,
      ),
    );
    return LockedFeatureSurface(
      locked: locked,
      title: title,
      requiredPackage: plan,
      borderRadius: 18,
      child: tile,
    );
  }
}

Map<String, bool> checkedFeaturesFromAudit(Map<String, dynamic>? audit) {
  final result = <String, bool>{};
  final list = audit?['checked_features'];
  if (list is List) {
    for (final item in list) {
      if (item is Map) {
        final key = item['feature']?.toString();
        if (key != null && key.isNotEmpty) {
          result[key] = item['enabled'] == true;
        }
      }
    }
  }
  return result;
}

bool lockedByFeature(Map<String, dynamic> features, String key) {
  if (!features.containsKey(key)) return false;
  return features[key] != true;
}

bool lockedByAnyFeature(Map<String, dynamic> features, Iterable<String> keys) {
  for (final key in keys) {
    if (lockedByFeature(features, key)) return true;
  }
  return false;
}
