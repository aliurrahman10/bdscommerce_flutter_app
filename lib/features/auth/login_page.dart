import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/models/api_exception.dart';
import '../../core/state/app_theme_controller.dart';
import '../../core/state/workspace_controller.dart';
import '../../shared/widgets/loading_button.dart';
import '../home/home_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _rememberKey = 'login_remember_enabled';
  static const _portalEmailKey = 'login_portal_email';
  static const _portalPasswordKey = 'login_portal_password';
  static const _storeEmailKey = 'login_store_email';
  static const _storePasswordKey = 'login_store_password';
  static const _storeTenantKey = 'login_store_tenant';

  late final TabController _tabController;
  final _portalEmail = TextEditingController();
  final _portalPassword = TextEditingController();
  final _storeEmail = TextEditingController();
  final _storePassword = TextEditingController();
  final _tenant = TextEditingController();
  bool _loading = false;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRememberedLogin();
  }

  Future<void> _loadRememberedLogin() async {
    final remember = await _storage.read(key: _rememberKey);
    final enabled = remember == null ? true : remember == '1';
    final values = await Future.wait([
      _storage.read(key: _portalEmailKey),
      _storage.read(key: _portalPasswordKey),
      _storage.read(key: _storeEmailKey),
      _storage.read(key: _storePasswordKey),
      _storage.read(key: _storeTenantKey),
    ]);
    if (!mounted) return;
    setState(() {
      _remember = enabled;
      if (enabled) {
        _portalEmail.text = values[0] ?? '';
        _portalPassword.text = values[1] ?? '';
        _storeEmail.text = values[2] ?? '';
        _storePassword.text = values[3] ?? '';
        _tenant.text = values[4] ?? '';
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _portalEmail.dispose();
    _portalPassword.dispose();
    _storeEmail.dispose();
    _storePassword.dispose();
    _tenant.dispose();
    super.dispose();
  }

  Future<void> _saveRememberedLogin() async {
    await _storage.write(key: _rememberKey, value: _remember ? '1' : '0');
    if (!_remember) {
      await Future.wait([
        _storage.delete(key: _portalEmailKey),
        _storage.delete(key: _portalPasswordKey),
        _storage.delete(key: _storeEmailKey),
        _storage.delete(key: _storePasswordKey),
        _storage.delete(key: _storeTenantKey),
      ]);
      return;
    }
    await Future.wait([
      _storage.write(key: _portalEmailKey, value: _portalEmail.text.trim()),
      _storage.write(key: _portalPasswordKey, value: _portalPassword.text),
      _storage.write(key: _storeEmailKey, value: _storeEmail.text.trim()),
      _storage.write(key: _storePasswordKey, value: _storePassword.text),
      _storage.write(key: _storeTenantKey, value: _tenant.text.trim()),
    ]);
  }

  Future<void> _loginPortal() async {
    await _run(() => context.read<WorkspaceController>().loginPortal(_portalEmail.text.trim(), _portalPassword.text));
  }

  Future<void> _loginStore() async {
    await _run(() => context.read<WorkspaceController>().loginStore(_storeEmail.text.trim(), _storePassword.text, _tenant.text.trim()));
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _loading = true);
    try {
      await task();
      await _saveRememberedLogin();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
    } on ApiException catch (e) {
      _show(e.message);
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeController>();
    final t = theme.t;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primary, Color(0xFFF6F8FB)],
            stops: [.0, .52],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  children: [
                    Container(
                      width: 118,
                      height: 118,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
                      child: Image.asset('assets/images/app_logo.png'),
                    ),
                    const SizedBox(height: 18),
                    const Text('BDS Commerce', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(t('Portal & Store Admin in one app', 'Portal & Store Admin এক app-এ'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TabBar(
                              controller: _tabController,
                              labelColor: AppTheme.primary,
                              unselectedLabelColor: AppTheme.muted,
                              indicatorSize: TabBarIndicatorSize.tab,
                              tabs: const [Tab(text: 'Client Portal'), Tab(text: 'Store Admin')],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 380,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _PortalLoginForm(
                                    email: _portalEmail,
                                    password: _portalPassword,
                                    loading: _loading,
                                    remember: _remember,
                                    onRememberChanged: (value) => setState(() => _remember = value),
                                    onSubmit: _loginPortal,
                                  ),
                                  _StoreLoginForm(
                                    email: _storeEmail,
                                    password: _storePassword,
                                    tenant: _tenant,
                                    loading: _loading,
                                    remember: _remember,
                                    onRememberChanged: (value) => setState(() => _remember = value),
                                    onSubmit: _loginStore,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalLoginForm extends StatelessWidget {
  const _PortalLoginForm({required this.email, required this.password, required this.loading, required this.remember, required this.onRememberChanged, required this.onSubmit});
  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final bool remember;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppThemeController>().t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Login to view billing, services and notifications.', 'Billing, service ও notification দেখতে login করুন।'), style: const TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 16),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Client email', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 8),
        CheckboxListTile(
          dense: true,
          value: remember,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(t('Remember email and password', 'Email/password remember রাখুন')),
          onChanged: (value) => onRememberChanged(value ?? true),
        ),
        const SizedBox(height: 8),
        LoadingButton(label: t('Login to Portal', 'Portal Login'), loading: loading, onPressed: onSubmit),
      ],
    );
  }
}

class _StoreLoginForm extends StatelessWidget {
  const _StoreLoginForm({required this.email, required this.password, required this.tenant, required this.loading, required this.remember, required this.onRememberChanged, required this.onSubmit});
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController tenant;
  final bool loading;
  final bool remember;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppThemeController>().t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Login to manage orders and store operations.', 'Order ও store operation manage করতে login করুন।'), style: const TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 16),
        TextField(controller: tenant, decoration: const InputDecoration(labelText: 'Store slug / domain', prefixIcon: Icon(Icons.storefront_outlined))),
        const SizedBox(height: 12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Store admin email', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 8),
        CheckboxListTile(
          dense: true,
          value: remember,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(t('Remember email, password and store', 'Email/password/store remember রাখুন')),
          onChanged: (value) => onRememberChanged(value ?? true),
        ),
        const SizedBox(height: 8),
        LoadingButton(label: t('Login to Store', 'Store Login'), loading: loading, onPressed: onSubmit),
      ],
    );
  }
}
