import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/core/navigation/app_shell.dart';

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
}
