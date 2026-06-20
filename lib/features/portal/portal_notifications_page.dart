import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class PortalNotificationsPage extends StatefulWidget {
  const PortalNotificationsPage({super.key});

  @override
  State<PortalNotificationsPage> createState() => _PortalNotificationsPageState();
}

class _PortalNotificationsPageState extends State<PortalNotificationsPage> {
  late Future<Map<String, dynamic>> _future;
  final Set<int> _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final workspace = context.read<WorkspaceController>();
    return workspace.portalApi.notifications(workspace.portalToken!);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
            final items = (snapshot.data?['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            if (items.isEmpty) {
              return const _EmptyNotifications();
            }
            return Scrollbar(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + bottomSafe),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  if (index == 0) return _NotificationHero(total: items.length);
                  final item = items[index - 1];
                  final expanded = _expanded.contains(index - 1);
                  return _PortalNotificationCard(
                    item: item,
                    expanded: expanded,
                    onTap: () {
                      setState(() {
                        if (expanded) {
                          _expanded.remove(index - 1);
                        } else {
                          _expanded.add(index - 1);
                        }
                      });
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationHero extends StatelessWidget {
  const _NotificationHero({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.dangerGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.glowShadow('rose_neon'),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -26,
            child: Icon(Icons.notifications_active_rounded, color: Colors.white.withOpacity(0.12), size: 125),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.17),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Updates', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('$total recent notification${total == 1 ? '' : 's'} from BDS', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortalNotificationCard extends StatelessWidget {
  const _PortalNotificationCard({required this.item, required this.expanded, required this.onTap});
  final Map<String, dynamic> item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString().trim().isNotEmpty == true ? item['title'].toString().trim() : 'Notification';
    final message = item['message']?.toString().trim() ?? '';
    final style = _NotificationStyle.fromTitle(title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: style.borderColor),
            boxShadow: AppTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(gradient: style.gradient, borderRadius: BorderRadius.circular(16)),
                      child: Icon(style.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.text, height: 1.15),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: style.softColor, borderRadius: BorderRadius.circular(999)),
                                child: Text(style.label, style: TextStyle(fontSize: 10.5, color: style.textColor, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            message,
                            maxLines: expanded ? null : 4,
                            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.muted, fontSize: 14.2, height: 1.42, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (message.length > 150) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.border)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(expanded ? 'Show less' : 'Read more', style: const TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.muted, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationStyle {
  const _NotificationStyle({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.softColor,
    required this.borderColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Gradient gradient;
  final Color softColor;
  final Color borderColor;
  final Color textColor;

  static _NotificationStyle fromTitle(String title) {
    final value = title.toLowerCase();
    if (value.contains('invoice') || value.contains('paid') || value.contains('payment')) {
      return const _NotificationStyle(
        icon: Icons.receipt_long_rounded,
        label: 'Billing',
        gradient: AppTheme.successGradient,
        softColor: Color(0xFFECFDF5),
        borderColor: Color(0xFFD1FAE5),
        textColor: Color(0xFF047857),
      );
    }
    if (value.contains('upgrade') || value.contains('downgrade') || value.contains('package') || value.contains('plan')) {
      return const _NotificationStyle(
        icon: Icons.swap_horiz_rounded,
        label: 'Plan',
        gradient: AppTheme.infoGradient,
        softColor: Color(0xFFE0F2FE),
        borderColor: Color(0xFFBAE6FD),
        textColor: Color(0xFF0369A1),
      );
    }
    if (value.contains('support') || value.contains('request') || value.contains('ticket')) {
      return const _NotificationStyle(
        icon: Icons.support_agent_rounded,
        label: 'Support',
        gradient: AppTheme.dangerGradient,
        softColor: Color(0xFFFDF2F8),
        borderColor: Color(0xFFFCE7F3),
        textColor: Color(0xFFBE185D),
      );
    }
    if (value.contains('onboarding') || value.contains('file') || value.contains('upload')) {
      return const _NotificationStyle(
        icon: Icons.cloud_upload_rounded,
        label: 'Onboarding',
        gradient: AppTheme.warningGradient,
        softColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFEF3C7),
        textColor: Color(0xFFB45309),
      );
    }
    return const _NotificationStyle(
      icon: Icons.notifications_active_rounded,
      label: 'Update',
      gradient: AppTheme.premiumGradient,
      softColor: Color(0xFFF1F5F9),
      borderColor: Color(0xFFE2E8F0),
      textColor: Color(0xFF475569),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded, color: AppTheme.muted2, size: 46),
              SizedBox(height: 10),
              Text('No notifications found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.text)),
              SizedBox(height: 4),
              Text('Important billing, support and service updates will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}
