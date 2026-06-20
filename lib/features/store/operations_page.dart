import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/locked_feature.dart';
import 'courier_settings_page.dart';
import 'coupons_page.dart';
import 'delivery_charges_page.dart';
import 'payment_methods_page.dart';
import 'admin_notification_settings_page.dart';

class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Operations', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.operationFeatures(workspace.activeStoreToken!),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          final allowedGateways = features['allowed_gateways'];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Premium Hero Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store Operations', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your store settings, couriers, and payments. ${allowedGateways != null ? 'Gateways: ${allowedGateways.toString()}' : ''}',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text('AVAILABLE MODULES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.muted, letterSpacing: 1.2)),
              ),

              _ActionTile(
                icon: Icons.confirmation_number_outlined,
                title: 'Coupons',
                subtitle: 'Discount, free shipping and usage limit',
                locked: features['coupons'] != true,
                requiredPackage: 'Scale',
                page: const CouponsPage(),
              ),
              _ActionTile(
                icon: Icons.local_shipping_outlined,
                title: 'Delivery Charges',
                subtitle: 'Manage inside/outside city shipping rates',
                locked: false,
                page: const DeliveryChargesPage(),
              ),
              _ActionTile(
                icon: Icons.payments_outlined,
                title: 'Payment Methods',
                subtitle: 'Configure COD, manual, bKash and SSLCommerz',
                locked: features['payment_gateways'] != true,
                requiredPackage: 'Launch+',
                page: const PaymentMethodsPage(),
              ),
              _ActionTile(
                icon: Icons.delivery_dining_outlined,
                title: 'Courier Settings',
                subtitle: 'Setup Pathao and Steadfast integrations',
                locked: features['courier_integrations'] != true,
                requiredPackage: 'Scale',
                page: const CourierSettingsPage(),
              ),
              _ActionTile(
                icon: Icons.notifications_active_outlined,
                title: 'Order Notifications',
                subtitle: 'Set up Email and Telegram alerts',
                locked: false,
                page: const AdminNotificationSettingsPage(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.page,
    this.requiredPackage = 'Scale',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final Widget page;
  final String requiredPackage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: LockedFeatureTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        locked: locked,
        requiredPackage: requiredPackage,
        onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}