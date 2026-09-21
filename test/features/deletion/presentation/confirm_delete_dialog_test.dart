import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/deletion/presentation/confirm_delete_dialog.dart';

void main() {
  testWidgets('confirming the dialog resolves true, cancelling resolves false', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showConfirmDeleteDialog(context, itemCount: 24);
          },
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 24 items permanently?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNot(true));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
