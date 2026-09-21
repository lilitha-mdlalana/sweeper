import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// A [FakeRepository] variant that counts fetches for pages >= 1 and can
/// optionally gate them behind a [Completer], to simulate a slow / in-flight
/// network fetch for reentrancy tests.
class DelayedFakeRepository implements MediaRepository {
  final List<MediaItem> allItems;
  int getMediaCallCountForPage1Plus = 0;
  Completer<void>? gate;

  DelayedFakeRepository(this.allItems);

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    if (page >= 1) {
      getMediaCallCountForPage1Plus++;
      if (gate != null) {
        await gate!.future;
      }
    }
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  test(
      'loadMoreIfNeeded appends the next page and hasMorePages becomes false when exhausted',
      () async {
    final items = List.generate(70, (i) => _item('item$i'));
    final repo = FakeRepository(items);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(galleryProvider.future);
    var state = container.read(galleryProvider).value!;
    expect(state.queue.length, 60);
    expect(state.hasMorePages, true);

    final notifier = container.read(galleryProvider.notifier);

    // Swipe through the first page until remaining <= 10, which triggers
    // loadMoreIfNeeded to fetch and append the second (final) page.
    for (var i = 0; i < 50; i++) {
      await notifier.swipe(SwipeAction.keep);
    }

    state = container.read(galleryProvider).value!;
    expect(state.queue.length, 70);
    expect(state.hasMorePages, false);
    expect(state.queue.map((e) => e.id).toSet().length, 70);

    // Finish swiping through the remainder to confirm no items were skipped
    // and the queue correctly reaches isDone.
    for (var i = 0; i < 20; i++) {
      await notifier.swipe(SwipeAction.keep);
    }

    state = container.read(galleryProvider).value!;
    expect(state.totalReviewed, 70);
    expect(state.isDone, true);
  });

  test('loadMoreIfNeeded is reentrancy-guarded against concurrent calls',
      () async {
    final items = List.generate(70, (i) => _item('item$i'));
    final repo = DelayedFakeRepository(items);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(galleryProvider.future);
    final notifier = container.read(galleryProvider.notifier);

    // Advance to remaining == 11, just before the fetch threshold, without
    // touching the (still ungated) page-1 fetch.
    for (var i = 0; i < 49; i++) {
      await notifier.swipe(SwipeAction.keep);
    }
    var state = container.read(galleryProvider).value!;
    expect(state.remaining, 11);

    // Gate the next page fetch so it stays in flight until we release it.
    final gate = Completer<void>();
    repo.gate = gate;

    // This swipe crosses the threshold (remaining becomes 10) and triggers
    // loadMoreIfNeeded internally, which will now hang on the gate.
    final swipeFuture = notifier.swipe(SwipeAction.keep);

    // Fire a second, concurrent loadMoreIfNeeded call while the first fetch
    // is still in flight. Without a reentrancy guard this would start a
    // second fetch of the same page, duplicating items and skipping a page.
    final secondCall = notifier.loadMoreIfNeeded();

    gate.complete();
    await swipeFuture;
    await secondCall;

    expect(repo.getMediaCallCountForPage1Plus, 1);
    state = container.read(galleryProvider).value!;
    expect(state.queue.length, 70);
    expect(state.queue.map((e) => e.id).toSet().length, 70);
    expect(state.hasMorePages, false);
  });

  test('swipe(delete) emits a lastSwipeEvents event', () async {
    final repo = FakeRepository([_item('a')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(galleryProvider.future);
    final notifier = container.read(galleryProvider.notifier);

    final future = notifier.lastSwipeEvents.first;
    await notifier.swipe(SwipeAction.delete);

    expect(await future, SwipeAction.delete);
  });
}
