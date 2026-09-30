import 'dart:io';
import 'dart:typed_data';
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
import 'package:sweeper/features/video_cleaner/domain/video_queue_state.dart';
import 'package:sweeper/features/video_cleaner/presentation/video_cleaner_providers.dart';

class FakeVideoRepository implements MediaRepository {
  final List<MediaItem> allVideos;
  FakeVideoRepository(this.allVideos);

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
    String? albumName,
  }) async =>
      MediaPage(items: [], hasMore: false);

  @override
  Future<MediaPage> getVideoMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
    String? albumName,
  }) async {
    final start = page * pageSize;
    if (start >= allVideos.length) return MediaPage(items: [], hasMore: false);
    final end = (start + pageSize).clamp(0, allVideos.length);
    return MediaPage(items: allVideos.sublist(start, end), hasMore: end < allVideos.length);
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('videoQueueProvider loads the first page of videos', () async {
    final repo = FakeVideoRepository([_video('a'), _video('b')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    final state = await container.read(videoQueueProvider.future);
    expect(state.items.map((i) => i.id).toList(), ['a', 'b']);
    expect(state.currentPageIndex, 0);
  });

  test('decide(delete) adds the item to the shared deletionQueueProvider', () async {
    final repo = FakeVideoRepository([_video('a', sizeBytes: 5000)]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    container.read(videoQueueProvider.notifier).decide('a', VideoDecision.delete);

    expect(container.read(deletionQueueProvider).items.map((i) => i.id), ['a']);
    expect(container.read(videoQueueProvider).value!.markedForDeletionCount, 1);
  });

  test('decide(keep) does not touch the deletion queue', () async {
    final repo = FakeVideoRepository([_video('a')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    container.read(videoQueueProvider.notifier).decide('a', VideoDecision.keep);

    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });

  test('undoFor after a delete removes the item from the deletion queue', () async {
    final repo = FakeVideoRepository([_video('a')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    container.read(videoQueueProvider.notifier).decide('a', VideoDecision.delete);
    container.read(videoQueueProvider.notifier).undoFor('a');

    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
    expect(container.read(videoQueueProvider).value!.markedForDeletionCount, 0);
  });

  test('changing a delete decision to keep removes the item from the deletion queue', () async {
    final repo = FakeVideoRepository([_video('a', sizeBytes: 5000), _video('b')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    final notifier = container.read(videoQueueProvider.notifier);
    notifier.decide('a', VideoDecision.delete);
    expect(container.read(deletionQueueProvider).items.map((i) => i.id), ['a']);

    notifier.decide('a', VideoDecision.keep);

    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
    expect(container.read(videoQueueProvider).value!.markedForDeletionCount, 0);
    expect(container.read(videoQueueProvider).value!.storageToReclaimBytes, 0);
  });

  test('undoFor targets the id it was called with, not the most recent decision on any video',
      () async {
    final repo = FakeVideoRepository([_video('a'), _video('b')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    final notifier = container.read(videoQueueProvider.notifier);

    notifier.decide('a', VideoDecision.delete);
    notifier.decide('b', VideoDecision.keep); // a later, unrelated decision on a different video

    notifier.undoFor('a'); // scoped: must undo a's delete, not b's keep

    final state = container.read(videoQueueProvider).value!;
    expect(state.decisions['a'], VideoDecision.undecided);
    expect(state.decisions['b'], VideoDecision.keep);
    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });

  test('deciding delete twice then undoing once leaves the item marked and still queued',
      () async {
    final repo = FakeVideoRepository([_video('a')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    final notifier = container.read(videoQueueProvider.notifier);

    notifier.decide('a', VideoDecision.delete);
    notifier.decide('a', VideoDecision.delete); // re-tapping Delete on an already-deleted item
    notifier.undoFor('a'); // pops only the second, redundant history entry

    final state = container.read(videoQueueProvider).value!;
    expect(state.decisions['a'], VideoDecision.delete);
    expect(container.read(deletionQueueProvider).items.map((i) => i.id), ['a']);
  });

  test('setCurrentPage records an implicit keep for the page being left if undecided', () async {
    final repo = FakeVideoRepository([_video('a'), _video('b')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    container.read(videoQueueProvider.notifier).setCurrentPage(1);

    final state = container.read(videoQueueProvider).value!;
    expect(state.currentPageIndex, 1);
    expect(state.decisions['a'], VideoDecision.keep);
    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });

  test('setCurrentPage does not override an explicit delete decision with implicit keep', () async {
    final repo = FakeVideoRepository([_video('a'), _video('b')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    container.read(videoQueueProvider.notifier).decide('a', VideoDecision.delete);
    container.read(videoQueueProvider.notifier).setCurrentPage(1);

    expect(container.read(videoQueueProvider).value!.decisions['a'], VideoDecision.delete);
  });

  test('loadMoreIfNeeded appends the next page once close to the end', () async {
    final items = List.generate(50, (i) => _video('v$i'));
    final repo = FakeVideoRepository(items);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.listen(videoQueueProvider, (_, _) {}); // keep the autoDispose provider alive for the test

    await container.read(videoQueueProvider.future);
    var state = container.read(videoQueueProvider).value!;
    expect(state.items.length, 40); // kVideoPageSize
    expect(state.hasMorePages, true);

    final notifier = container.read(videoQueueProvider.notifier);
    notifier.setCurrentPage(31); // items.length - index = 9 <= 10
    await Future<void>.delayed(Duration.zero);

    state = container.read(videoQueueProvider).value!;
    expect(state.items.length, 50);
    expect(state.hasMorePages, false);
  });
}
