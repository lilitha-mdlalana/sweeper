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
import 'package:sweeper/features/gallery/presentation/home_screen.dart';

/// A minimal valid 1x1 transparent PNG, used so [Image.memory] can decode it
/// without throwing (a decode error would otherwise be caught by the test
/// framework as an unexpected exception).
final _fakeThumbnailBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakeRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    if (page > 0) return MediaPage(items: [], hasMore: false);
    return MediaPage(
      items: List.generate(
        3,
        (i) => MediaItem(
          id: 'id$i',
          dateTaken: DateTime(2024, 1, 1),
          sizeBytes: 1000,
          width: 100,
          height: 100,
        ),
      ),
      hasMore: false,
    );
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async =>
      _fakeThumbnailBytes;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

class EmptyRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async =>
      MediaPage(items: [], hasMore: false);

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

/// Simulates an item deleted externally since load: `getThumbnail` resolves
/// to null for every item, so the current card should auto-skip instead of
/// hanging.
class VanishedItemsRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    if (page > 0) return MediaPage(items: [], hasMore: false);
    return MediaPage(
      items: List.generate(
        2,
        (i) => MediaItem(
          id: 'gone$i',
          dateTaken: DateTime(2024, 1, 1),
          sizeBytes: 1000,
          width: 100,
          height: 100,
        ),
      ),
      hasMore: false,
    );
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen shows the remaining count from galleryProvider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(FakeRepository())],
      child: MaterialApp(home: HomeScreen(onReviewDeletions: () {})),
    ));

    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('remaining'), findsOneWidget);
  });

  testWidgets('HomeScreen shows an empty-gallery message when there are no photos',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(EmptyRepository())],
      child: MaterialApp(home: HomeScreen(onReviewDeletions: () {})),
    ));

    await tester.pumpAndSettle();

    expect(find.text('No photos to clean. Your gallery is empty.'), findsOneWidget);
  });

  testWidgets(
      'HomeScreen auto-skips through items whose thumbnails resolve to null instead of hanging',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(VanishedItemsRepository())],
      child: MaterialApp(home: HomeScreen(onReviewDeletions: () {})),
    ));

    await tester.pumpAndSettle();

    // Both items had null thumbnails, so the gallery auto-skips past both
    // and lands on the Done screen rather than hanging on a placeholder.
    expect(find.text('No photos to clean. Your gallery is empty.'), findsNothing);
    expect(find.textContaining('remaining'), findsNothing);
  });
}
