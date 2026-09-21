// Basic smoke test for the Sweep app's root widget.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sweeper/main.dart';
import 'package:sweeper/features/settings/presentation/permission_providers.dart';

class _GrantedPermissionNotifier extends PermissionStatusNotifier {
  @override
  Future<PermissionState> build() async => PermissionState.granted;
}

void main() {
  testWidgets('SweepApp shows the bottom nav shell with all tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionStatusProvider.overrideWith(_GrantedPermissionNotifier.new),
        ],
        child: const SweepApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Review'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
