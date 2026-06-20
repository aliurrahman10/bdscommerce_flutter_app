import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_copy.dart';
import '../../core/config/app_language.dart';
import '../../core/state/app_theme_controller.dart';

class RenewalWarningBanner extends StatelessWidget {
  const RenewalWarningBanner({
    super.key,
    required this.payload,
    required this.copy,
    required this.onRenewNow,
  });

  final Map<String, dynamic> payload;
  final AppCopy copy;
  final VoidCallback onRenewNow;

  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerDeep = Color(0xFF7F1D1D);
  static const Color _dangerSoft = Color(0xFFFFF1F2);
  static const Color _dangerTint = Color(0xFFFFE4E6);
  static const Color _dangerBorder = Color(0xFFFECACA);

  @override
  Widget build(BuildContext context) {
    final info = RenewalInfo.fromPayload(payload);
    if (info == null || info.daysLeft > 3 || info.daysLeft < 0) {
      return const SizedBox.shrink();
    }

    final theme = context.watch<AppThemeController>();
    final lang = theme.language;
    final dueLabel = DateFormat('dd MMM yyyy').format(info.date);
    final remaining = _remainingLabel(lang, info.daysLeft);
    final title = copy.localized(
      lang,
      'renewal_warning_title',
      en: 'Renewal alert',
      bn: 'Renewal alert',
    );
    final fallbackMessage = lang.isBangla
        ? 'Next renewal date $dueLabel। Service interruption এড়াতে এখনই renew করুন।'
        : 'Next renewal date is $dueLabel. Renew now to avoid service interruption.';
    final messageTemplate = copy.localized(
      lang,
      'renewal_warning_message',
      en: fallbackMessage,
      bn: fallbackMessage,
    );
    final message = messageTemplate.contains('{date}') ? messageTemplate.replaceAll('{date}', dueLabel) : messageTemplate;
    final button = copy.localized(lang, 'renewal_warning_button', en: 'Renew Now', bn: 'Renew Now');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _dangerSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dangerBorder),
        boxShadow: [
          BoxShadow(
            color: _danger.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _dangerBorder),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: _danger, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _dangerDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    _RenewalPill(label: remaining, strong: true),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: _dangerDeep.withOpacity(0.78),
                    fontWeight: FontWeight.w400,
                    height: 1.32,
                    fontSize: 12.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _RenewalPill(label: lang.isBangla ? 'Next renewal: $dueLabel' : 'Next renewal: $dueLabel'),
                    _RenewalPill(label: remaining),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onRenewNow,
                  icon: const Icon(Icons.flash_on_rounded, size: 17),
                  label: Text(button, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _remainingLabel(AppLanguage lang, int daysLeft) {
    if (daysLeft <= 0) return lang.isBangla ? 'Today' : 'Today';
    if (daysLeft == 1) return lang.isBangla ? 'Tomorrow' : 'Tomorrow';
    return lang.isBangla ? '$daysLeft Days remaining' : '$daysLeft Days remaining';
  }
}

class _RenewalPill extends StatelessWidget {
  const _RenewalPill({required this.label, this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: strong ? 9 : 8, vertical: strong ? 5 : 4),
      decoration: BoxDecoration(
        color: strong ? RenewalWarningBanner._danger : RenewalWarningBanner._dangerTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: strong ? RenewalWarningBanner._danger : RenewalWarningBanner._dangerBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: strong ? Colors.white : RenewalWarningBanner._dangerDeep,
          fontSize: strong ? 11.5 : 11,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class RenewalInfo {
  const RenewalInfo({required this.date, required this.daysLeft});

  final DateTime date;
  final int daysLeft;

  static RenewalInfo? fromPayload(Map<String, dynamic> payload) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = <DateTime>[];
    _scan(payload, dates);
    if (dates.isEmpty) return null;

    dates.sort();
    for (final date in dates) {
      final normalized = DateTime(date.year, date.month, date.day);
      final days = normalized.difference(today).inDays;
      if (days >= 0) return RenewalInfo(date: normalized, daysLeft: days);
    }
    return null;
  }

  static void _scan(dynamic value, List<DateTime> dates) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final current = entry.value;
        final looksLikeRenewalDate = key.contains('next_due') ||
            key.contains('service_next_due') ||
            key.contains('renewal_date') ||
            key.contains('renewal_due') ||
            key == 'due_date' ||
            key.contains('expires_at') ||
            key.contains('expiry_date') ||
            key.contains('current_period_ends');
        if (looksLikeRenewalDate && current != null) {
          final parsed = DateTime.tryParse(current.toString());
          if (parsed != null) dates.add(parsed);
        }
        if (current is Map || current is List) _scan(current, dates);
      }
    } else if (value is List) {
      for (final item in value) {
        _scan(item, dates);
      }
    }
  }
}
