import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/domain/swipe_action.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';

class FakeRepository implements MediaRepository {
  final List<MediaItem> allItems;
  FakeRepository(this.allItems);

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    final start = page * pageSize;
    if (start >= allItems.length) return MediaPage(items: [], hasMore: false);
    final end = (start + pageSize).clamp(0, allItems.length);
    return MediaPage(items: allItems.sublist(start, end), hasMore: end < allItems.length);
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

MediaItem _item(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
    );

void main() {
  test('galleryProvider loads the first page and swipe advances the queue', () async {
    final repo = FakeRepository([_item('a'), _item('b')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(galleryProvider.future);
    expect(container.read(galleryProvider).value!.queue.length, 2);

    await container.read(galleryProvider.notifier).swipe(SwipeAction.delete);
    final state = container.read(galleryProvider).value!;
    expect(state.currentIndex, 1);
    expect(state.totalMarkedForDeletion, 1);
  });
}
