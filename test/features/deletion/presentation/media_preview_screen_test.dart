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
import 'package:sweeper/features/deletion/presentation/media_preview_screen.dart';

class OneByOnePngRepository implements MediaRepository {
  static final _onePixelPng = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
    8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207,
    192, 0, 0, 3, 1, 1, 0, 24, 221, 141, 176, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);

  @override
  Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);
  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => _onePixelPng;
  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => _onePixelPng;
  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: [], failedIds: []);
}

void main() {
  testWidgets('MediaPreviewScreen renders the image once bytes load', (tester) async {
    final item = MediaItem(id: 'a', dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1);

    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(OneByOnePngRepository())],
      child: MaterialApp(home: MediaPreviewScreen(item: item)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });
}
