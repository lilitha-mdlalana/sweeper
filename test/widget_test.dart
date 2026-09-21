// Basic smoke test for the Sweep app's root widget.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sweeper/main.dart';

void main() {
  testWidgets('SweepApp shows the bottom nav shell with all tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SweepApp());

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Review'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
