import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';
import '../auth/login_page.dart';
import '../home/home_shell.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 900), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final workspace = context.read<WorkspaceController>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => workspace.hasAnySession ? const HomeShell() : const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(42),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 40, offset: const Offset(0, 18))],
          ),
          padding: const EdgeInsets.all(24),
          child: Image.asset('assets/images/app_logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}
