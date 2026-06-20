import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bds_commerce_mobile/core/config/app_theme.dart';
import 'package:bds_commerce_mobile/core/state/app_theme_controller.dart';
import 'package:bds_commerce_mobile/core/state/workspace_controller.dart';
import 'package:bds_commerce_mobile/features/auth/login_page.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => WorkspaceController()),
          ChangeNotifierProvider(create: (_) => AppThemeController()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const LoginPage(),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    expect(find.text('BDS Commerce'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
