import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_theme.dart';
import 'core/services/push_token_service.dart';
import 'core/state/app_theme_controller.dart';
import 'core/state/workspace_controller.dart';
import 'features/splash/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkspaceController()..load()),
        ChangeNotifierProvider(create: (_) => AppThemeController()..load()),
      ],
      child: const BdsCommerceApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushTokenService.instance.warmUp();
  });
}

class BdsCommerceApp extends StatelessWidget {
  const BdsCommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeController>();
    return MaterialApp(
      title: 'BDS Commerce',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(themeKey: theme.selectedThemeKey),
      builder: (context, child) {
        // Keep every pushed page, long list and bottom action above Android/iOS
        // system navigation controls. This prevents buttons/cards from sitting
        // underneath the device back/home/navigation area on small phones.
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashPage(),
    );
  }
}
