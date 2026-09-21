import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/presentation/done_screen.dart';

void main() {
  testWidgets('DoneScreen shows totals and wires both buttons', (tester) async {
    var reviewTapped = false;
    var startAgainTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: DoneScreen(
        totalReviewed: 428,
        totalMarkedForDeletion: 87,
        onReviewDeletions: () => reviewTapped = true,
        onStartAgain: () => startAgainTapped = true,
      ),
    ));

    expect(find.textContaining('428'), findsWidgets);
    expect(find.textContaining('87'), findsWidgets);

    await tester.tap(find.text('Review deletions'));
    expect(reviewTapped, isTrue);

    await tester.tap(find.text('Start again'));
    expect(startAgainTapped, isTrue);
  });
}
