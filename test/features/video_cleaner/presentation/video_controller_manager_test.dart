import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/video_cleaner/presentation/video_controller_manager.dart';

/// Counts getVideoFile calls per item id and can gate them behind a
/// Completer, so a test can force two ensureController calls for the same
/// item to overlap without touching the video_player platform channel
/// (getVideoFile returning null short-circuits ensureController before it
/// ever constructs a VideoPlayerController).
class _CountingRepository implements MediaRepository {
  final Map<String, int> callCounts = {};
  Completer<void>? gate;

  @override
  Future<File?> getVideoFile(MediaItem item) async {
    callCounts[item.id] = (callCounts[item.id] ?? 0) + 1;
    if (gate != null) await gate!.future;
    return null;
  }

  @override
  Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);
  @override
  Future<MediaPage> getVideoMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);
  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;
  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;
  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: [], failedIds: []);
}

MediaItem _video(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
      type: MediaType.video,
    );

void main() {
  group('neighborIds', () {
    test('at the start of the list: current and next only, no previous', () {
      final items = [_video('a'), _video('b'), _video('c')];
      expect(neighborIds(items, 0), ['a', 'b']);
    });

    test('in the middle: previous, current, next', () {
      final items = [_video('a'), _video('b'), _video('c')];
      expect(neighborIds(items, 1), ['a', 'b', 'c']);
    });

    test('at the end of the list: previous and current only, no next', () {
      final items = [_video('a'), _video('b'), _video('c')];
      expect(neighborIds(items, 2), ['b', 'c']);
    });

    test('single-item list: just current', () {
      final items = [_video('a')];
      expect(neighborIds(items, 0), ['a']);
    });
  });

  group('ensureController concurrency', () {
    test('two concurrent calls for the same item share one repository fetch', () async {
      final repo = _CountingRepository();
      final manager = VideoControllerManager(repo);
      final gate = Completer<void>();
      repo.gate = gate;

      final first = manager.ensureController(_video('a'));
      final second = manager.ensureController(_video('a'));
      gate.complete();
      await first;
      await second;

      expect(repo.callCounts['a'], 1);
    });

    test('ensureController after disposeAll returns null and fetches nothing new', () async {
      final repo = _CountingRepository();
      final manager = VideoControllerManager(repo);
      manager.disposeAll();

      final result = await manager.ensureController(_video('a'));

      expect(result, isNull);
      expect(repo.callCounts['a'], isNull);
    });
  });
}
