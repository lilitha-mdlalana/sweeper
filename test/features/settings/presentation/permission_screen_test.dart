import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/settings/presentation/permission_screen.dart';

void main() {
  testWidgets('tapping Allow photo access invokes onAllowPressed', (tester) async {
    var allowTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: PermissionScreen(
        onAllowPressed: () => allowTapped = true,
        onPrivacyPressed: () {},
      ),
    ));

    await tester.tap(find.text('Allow photo access'));
    expect(allowTapped, isTrue);
  });

  testWidgets('tapping privacy link invokes onPrivacyPressed', (tester) async {
    var privacyTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: PermissionScreen(
        onAllowPressed: () {},
        onPrivacyPressed: () => privacyTapped = true,
      ),
    ));

    await tester.tap(find.text('Read the privacy details'));
    expect(privacyTapped, isTrue);
  });
}
