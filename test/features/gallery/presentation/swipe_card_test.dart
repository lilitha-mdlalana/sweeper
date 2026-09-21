import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/presentation/swipe_card.dart';
import 'package:sweeper/features/gallery/domain/swipe_action.dart';

void main() {
  testWidgets('dragging left past the threshold reports SwipeAction.delete',
      (tester) async {
    SwipeAction? reported;
    await tester.pumpWidget(MaterialApp(
      home: SwipeCard(
        onSwiped: (a) => reported = a,
        child: Container(width: 300, height: 400, color: Colors.blue),
      ),
    ));

    await tester.drag(find.byType(SwipeCard), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(reported, SwipeAction.delete);
  });

  testWidgets('dragging right past the threshold reports SwipeAction.keep',
      (tester) async {
    SwipeAction? reported;
    await tester.pumpWidget(MaterialApp(
      home: SwipeCard(
        onSwiped: (a) => reported = a,
        child: Container(width: 300, height: 400, color: Colors.blue),
      ),
    ));

    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(reported, SwipeAction.keep);
  });

  testWidgets('dragging up reports favourite, down reports skip', (tester) async {
    SwipeAction? reported;
    await tester.pumpWidget(MaterialApp(
      home: SwipeCard(
        onSwiped: (a) => reported = a,
        child: Container(width: 300, height: 400, color: Colors.blue),
      ),
    ));

    await tester.drag(find.byType(SwipeCard), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(reported, SwipeAction.favourite);
  });
}
