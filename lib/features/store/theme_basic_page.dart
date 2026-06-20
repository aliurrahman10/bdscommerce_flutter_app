import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/workspace_controller.dart';

class ThemeBasicPage extends StatefulWidget {
  const ThemeBasicPage({super.key});

  @override
  State<ThemeBasicPage> createState() => _ThemeBasicPageState();
}

class _ThemeBasicPageState extends State<ThemeBasicPage> {
  late Future<Map<String, dynamic>> _future;
  final _siteName = TextEditingController();
  final _tagline = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  bool _showRating = true;
  bool _showAddToCart = true;
  bool _showBadges = true;
  bool _bottomNav = true;
  bool _stickyHeader = true;
  bool _footerPaymentIcons = true;
  String _productCardStyle = 'grid_1';
  String _sliderCardStyle = 'slide_1';
  String _headerStyle = 'header_1';
  List<String> _allowedProductStyles = const ['grid_1'];
  List<String> _allowedSliderStyles = const ['slide_1'];
  List<String> _allowedHeaderStyles = const ['header_1'];
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final workspace = context.read<WorkspaceController>();
    final response = await workspace.storeApi.themeBasic(workspace.activeStoreToken!);
    if (!_loaded) _apply(response);
    return response;
  }

  List<String> _list(dynamic value, List<String> fallback) {
    final items = (value as List<dynamic>? ?? fallback).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return items.isEmpty ? fallback : items;
  }

  void _apply(Map<String, dynamic> response) {
    final settings = response['settings'] as Map<String, dynamic>? ?? {};
    final theme = response['theme'] as Map<String, dynamic>? ?? {};
    final caps = response['capabilities'] as Map<String, dynamic>? ?? {};
    final colors = theme['colors'] as Map<String, dynamic>? ?? {};
    final productCard = theme['product_card'] as Map<String, dynamic>? ?? {};
    final mobile = theme['mobile'] as Map<String, dynamic>? ?? {};
    final header = theme['header'] as Map<String, dynamic>? ?? {};
    final footer = theme['footer'] as Map<String, dynamic>? ?? {};

    _allowedProductStyles = _list(caps['allowed_product_card_styles'], const ['grid_1']);
    _allowedSliderStyles = _list(caps['allowed_slider_card_styles'], const ['slide_1']);
    _allowedHeaderStyles = _list(caps['allowed_header_styles'], const ['header_1']);

    _siteName.text = settings['site_name']?.toString() ?? '';
    _tagline.text = settings['site_tagline']?.toString() ?? '';
    _email.text = settings['contact_email']?.toString() ?? '';
    _phone.text = settings['contact_phone']?.toString() ?? '';
    _whatsapp.text = settings['contact_whatsapp']?.toString() ?? '';
    _primary.text = colors['primary']?.toString() ?? '#0F5A66';
    _secondary.text = colors['secondary']?.toString() ?? '#F97316';
    _productCardStyle = productCard['style']?.toString() ?? _allowedProductStyles.first;
    _sliderCardStyle = productCard['slider_style']?.toString() ?? _allowedSliderStyles.first;
    _headerStyle = header['style']?.toString() ?? _allowedHeaderStyles.first;
    if (!_allowedProductStyles.contains(_productCardStyle)) _productCardStyle = _allowedProductStyles.first;
    if (!_allowedSliderStyles.contains(_sliderCardStyle)) _sliderCardStyle = _allowedSliderStyles.first;
    if (!_allowedHeaderStyles.contains(_headerStyle)) _headerStyle = _allowedHeaderStyles.first;
    _showRating = productCard['show_rating'] != false;
    _showAddToCart = productCard['show_add_to_cart'] != false;
    _showBadges = productCard['show_badges'] != false;
    _bottomNav = mobile['bottom_nav'] != false;
    _stickyHeader = header['sticky'] != false;
    _footerPaymentIcons = footer['show_payment_icons'] != false;
    _loaded = true;
  }

  void _refresh() {
    _loaded = false;
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      await workspace.storeApi.updateThemeBasic(workspace.activeStoreToken!, {
        'settings': {
          'site_name': _siteName.text.trim(),
          'site_tagline': _tagline.text.trim(),
          'contact_email': _email.text.trim(),
          'contact_phone': _phone.text.trim(),
          'contact_whatsapp': _whatsapp.text.trim(),
        },
        'theme': {
          'colors': {'primary': _primary.text.trim(), 'secondary': _secondary.text.trim()},
          'product_card': {
            'style': _productCardStyle,
            'slider_style': _sliderCardStyle,
            'show_rating': _showRating,
            'show_add_to_cart': _showAddToCart,
            'show_badges': _showBadges,
          },
          'mobile': {'bottom_nav': _bottomNav},
          'header': {'style': _headerStyle, 'sticky': _stickyHeader},
          'footer': {'show_payment_icons': _footerPaymentIcons},
        },
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Theme settings saved.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _siteName.dispose();
    _tagline.dispose();
    _email.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  String _label(String value) {
    return value
        .replaceAll('grid_', 'Product Card ')
        .replaceAll('slide_', 'Slider Card ')
        .replaceAll('header_', 'Header ')
        .replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic Theme Settings'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save Settings')),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Site Identity', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              _Input(controller: _siteName, label: 'Site name'),
              _Input(controller: _tagline, label: 'Tagline'),
              _Input(controller: _email, label: 'Contact email'),
              _Input(controller: _phone, label: 'Contact phone'),
              _Input(controller: _whatsapp, label: 'WhatsApp number'),
              const SizedBox(height: 14),
              const Text('Preset Styles', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _headerStyle,
                decoration: const InputDecoration(labelText: 'Header preset'),
                items: _allowedHeaderStyles.map((value) => DropdownMenuItem(value: value, child: Text(_label(value)))).toList(),
                onChanged: (value) => setState(() => _headerStyle = value ?? _headerStyle),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _productCardStyle,
                decoration: const InputDecoration(labelText: 'Product card style'),
                items: _allowedProductStyles.map((value) => DropdownMenuItem(value: value, child: Text(_label(value)))).toList(),
                onChanged: (value) => setState(() => _productCardStyle = value ?? _productCardStyle),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _sliderCardStyle,
                decoration: const InputDecoration(labelText: 'Product slider card style'),
                items: _allowedSliderStyles.map((value) => DropdownMenuItem(value: value, child: Text(_label(value)))).toList(),
                onChanged: (value) => setState(() => _sliderCardStyle = value ?? _sliderCardStyle),
              ),
              const SizedBox(height: 14),
              const Text('Colors', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: _Input(controller: _primary, label: 'Primary color')), const SizedBox(width: 10), Expanded(child: _Input(controller: _secondary, label: 'Secondary color'))]),
              const SizedBox(height: 14),
              const Text('Basic Toggles', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              SwitchListTile(value: _showRating, onChanged: (v) => setState(() => _showRating = v), title: const Text('Show product rating')),
              SwitchListTile(value: _showAddToCart, onChanged: (v) => setState(() => _showAddToCart = v), title: const Text('Show add to cart')),
              SwitchListTile(value: _showBadges, onChanged: (v) => setState(() => _showBadges = v), title: const Text('Show badges')),
              SwitchListTile(value: _bottomNav, onChanged: (v) => setState(() => _bottomNav = v), title: const Text('Mobile bottom nav')),
              SwitchListTile(value: _stickyHeader, onChanged: (v) => setState(() => _stickyHeader = v), title: const Text('Sticky header')),
              SwitchListTile(value: _footerPaymentIcons, onChanged: (v) => setState(() => _footerPaymentIcons = v), title: const Text('Footer payment icons')),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
      );
}
