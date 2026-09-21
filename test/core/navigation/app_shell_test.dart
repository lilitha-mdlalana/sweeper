import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/core/navigation/app_shell.dart';
import 'package:sweeper/core/theme/app_colors.dart';
import 'package:sweeper/core/theme/app_theme.dart';

void main() {
  testWidgets('AppShell shows Home tab by default and switches to Settings on tap',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AppShell())));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-page')), findsOneWidget);
  });

  testWidgets('AppShell NavigationBar resolves to AppColors.navBackground via AppTheme.light',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );

    final BuildContext context = tester.element(find.byType(NavigationBar));
    final resolvedBackgroundColor = NavigationBarTheme.of(context).backgroundColor;

    expect(resolvedBackgroundColor, AppColors.navBackground);
  });
}
