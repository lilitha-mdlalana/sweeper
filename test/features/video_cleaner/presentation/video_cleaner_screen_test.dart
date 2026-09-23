import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';
import 'package:sweeper/features/deletion/presentation/deletion_providers.dart';
import 'package:sweeper/features/video_cleaner/presentation/video_cleaner_screen.dart';

/// Returns null for both the thumbnail and the playback file, so the pager
/// falls back to its no-poster icon rather than touching the video_player
/// platform channel (which has no test double set up in this project).
class FakeVideoOnlyRepository implements MediaRepository {
  final List<MediaItem> videos;
  FakeVideoOnlyRepository(this.videos);

  @override
  Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);

  @override
  Future<MediaPage> getVideoMedia({required int page, required int pageSize, required SortOrder sort}) async {
    if (page > 0) return MediaPage(items: [], hasMore: false);
    return MediaPage(items: videos, hasMore: false);
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<File?> getVideoFile(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

MediaItem _video(String id, {int sizeBytes = 1000}) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: sizeBytes,
      width: 100,
      height: 100,
      type: MediaType.video,
      durationMs: 5000,
    );

Future<void> _pump(WidgetTester tester, MediaRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [mediaRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: VideoCleanerScreen(onReviewDeletions: () {})),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when there are no videos', (tester) async {
    await _pump(tester, FakeVideoOnlyRepository([]));

    expect(find.text('No videos to clean. Your video library is already empty.'), findsOneWidget);
  });

  testWidgets('shows position header and Delete/Keep buttons for the first video', (tester) async {
    await _pump(tester, FakeVideoOnlyRepository([_video('a'), _video('b'), _video('c')]));

    expect(find.text('Videos  1/3'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Keep'), findsOneWidget);
  });

  testWidgets('tapping Delete marks the current video and adds it to the deletion queue', (tester) async {
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(FakeVideoOnlyRepository([_video('a'), _video('b')])),
    ]);
    addTearDown(container.dispose);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: VideoCleanerScreen(onReviewDeletions: () {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(container.read(deletionQueueProvider).items.map((i) => i.id), ['a']);
  });

  testWidgets('tapping Keep does not touch the deletion queue', (tester) async {
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(FakeVideoOnlyRepository([_video('a'), _video('b')])),
    ]);
    addTearDown(container.dispose);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: VideoCleanerScreen(onReviewDeletions: () {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });

  testWidgets('reviewing every video shows the end-of-session screen with correct totals',
      (tester) async {
    await _pump(tester, FakeVideoOnlyRepository([_video('a'), _video('b')]));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2'), findsWidgets); // totalReviewed
    expect(find.text('Review Deletions'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
