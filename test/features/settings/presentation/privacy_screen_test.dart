import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/settings/presentation/privacy_screen.dart';

void main() {
  testWidgets('PrivacyScreen shows all four privacy bullets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));

    expect(find.text('Nothing is uploaded'), findsOneWidget);
    expect(find.text('No account'), findsOneWidget);
    expect(find.text('Processed on this device'), findsOneWidget);
    expect(find.text('You confirm every deletion'), findsOneWidget);
  });
}
