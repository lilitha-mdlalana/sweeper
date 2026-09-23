import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/video_cleaner/presentation/video_end_screen.dart';

void main() {
  testWidgets('VideoEndScreen shows totals and wires both buttons', (tester) async {
    var reviewTapped = false;
    var doneTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: VideoEndScreen(
        totalReviewed: 184,
        totalMarkedForDeletion: 12,
        storageToReclaimBytes: 3 * 1024 * 1024 * 1024 + 700 * 1024 * 1024, // ~3.7GB
        onReviewDeletions: () => reviewTapped = true,
        onDone: () => doneTapped = true,
      ),
    ));

    expect(find.textContaining('184'), findsWidgets);
    expect(find.textContaining('12'), findsWidgets);
    expect(find.textContaining('3.7 GB'), findsWidgets);

    await tester.tap(find.text('Review Deletions'));
    expect(reviewTapped, isTrue);

    await tester.tap(find.text('Done'));
    expect(doneTapped, isTrue);
  });
}
