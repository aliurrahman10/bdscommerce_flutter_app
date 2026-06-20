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
      appBar: AppBar(title: const Text('Operations')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: workspace.storeApi.operationFeatures(workspace.activeStoreToken!),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final features = snapshot.data?['features'] as Map<String, dynamic>? ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(features: features),
              const SizedBox(height: 14),
              _ActionTile(icon: Icons.confirmation_number_outlined, title: 'Coupons', subtitle: 'Discount, free shipping and usage limit', locked: features['coupons'] != true, requiredPackage: 'Scale', page: const CouponsPage()),
              _ActionTile(icon: Icons.local_shipping_outlined, title: 'Delivery Charges', subtitle: 'Inside/outside city delivery charges', locked: false, page: const DeliveryChargesPage()),
              _ActionTile(icon: Icons.payments_outlined, title: 'Payment Methods', subtitle: 'COD, manual, bKash and SSLCommerz', locked: features['payment_gateways'] != true, requiredPackage: 'Launch+', page: const PaymentMethodsPage()),
              _ActionTile(icon: Icons.delivery_dining_outlined, title: 'Courier Settings', subtitle: 'Pathao and Steadfast settings', locked: features['courier_integrations'] != true, requiredPackage: 'Scale', page: const CourierSettingsPage()),
              _ActionTile(icon: Icons.notifications_active_outlined, title: 'Admin Order Notifications', subtitle: 'Email and Telegram alerts for new orders', locked: false, page: const AdminNotificationSettingsPage()),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.features});
  final Map<String, dynamic> features;

  @override
  Widget build(BuildContext context) {
    final allowedGateways = features['allowed_gateways'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Plan synced operations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 6),
        Text('Mobile admin follows same package feature rules as web admin. Allowed gateways: ${allowedGateways is List ? allowedGateways.join(', ') : 'All available'}', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.locked, required this.page, this.requiredPackage = 'Scale'});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final Widget page;
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