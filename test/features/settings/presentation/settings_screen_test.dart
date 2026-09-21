import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweeper/features/settings/presentation/settings_screen.dart';
import 'package:sweeper/features/settings/presentation/settings_providers.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping Oldest updates settingsProvider sort order', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oldest'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).value?.sortOrder, SortOrder.oldestFirst);
  });

  testWidgets('toggling confirm switch updates settingsProvider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).value?.confirmBeforeDelete, isFalse);
  });

  testWidgets('the About Sweep row has no chevron, since it has no destination',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('About Sweep'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    final aboutTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('About Sweep'), matching: find.byType(ListTile)),
    );
    expect(aboutTile.trailing, isNull);
    expect(aboutTile.onTap, isNull);

    // Privacy, which does navigate, keeps its chevron.
    final privacyTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Privacy'), matching: find.byType(ListTile)),
    );
    expect(privacyTile.trailing, isNotNull);
  });
}
