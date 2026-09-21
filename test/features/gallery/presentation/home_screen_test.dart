import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';
import 'package:sweeper/features/gallery/presentation/home_screen.dart';

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
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

void main() {
  testWidgets('HomeScreen shows the remaining count from galleryProvider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(FakeRepository())],
      child: const MaterialApp(home: HomeScreen()),
    ));

    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('remaining'), findsOneWidget);
  });
}
