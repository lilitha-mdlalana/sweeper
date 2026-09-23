import 'package:video_player/video_player.dart';
import '../../gallery/domain/media_item.dart';
import '../../gallery/domain/media_repository.dart';

/// The ids to keep controllers warm for: previous, current, next around
/// [currentIndex] — never the whole list, so memory stays bounded regardless
/// of library size.
List<String> neighborIds(List<MediaItem> items, int currentIndex) {
  final ids = <String>[];
  if (currentIndex > 0) ids.add(items[currentIndex - 1].id);
  if (currentIndex >= 0 && currentIndex < items.length) {
    ids.add(items[currentIndex].id);
  }
  if (currentIndex + 1 < items.length) ids.add(items[currentIndex + 1].id);
  return ids;
}

/// Caches at most prev/current/next [VideoPlayerController]s, keyed by
/// [MediaItem.id]. Controllers outside the window are disposed aggressively
/// so review sessions over large libraries stay bounded in memory.
///
/// Only the current page is ever played — prev/next are initialized (so the
/// first frame is ready, cutting switch latency) but never started.
class VideoControllerManager {
  final MediaRepository repo;
  final _cache = <String, VideoPlayerController>{};
  final _inFlight = <String, Future<VideoPlayerController?>>{};
  bool _disposed = false;

  VideoControllerManager(this.repo);

  VideoPlayerController? controllerFor(String id) => _cache[id];

  Iterable<String> get cachedIds => _cache.keys;

  /// Fetches/initializes the controller for [item], reusing any cached or
  /// already-in-flight request for the same id so two overlapping calls
  /// (e.g. two page-settle passes racing on a fast swipe) never construct
  /// two controllers for one item — the second would otherwise silently
  /// overwrite the cache entry and leak the first, never-disposed one.
  Future<VideoPlayerController?> ensureController(MediaItem item) async {
    if (_disposed) return null;

    final cached = _cache[item.id];
    if (cached != null) return cached;

    final pending = _inFlight[item.id];
    if (pending != null) return pending;

    final future = _createController(item);
    _inFlight[item.id] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(item.id);
    }
  }

  Future<VideoPlayerController?> _createController(MediaItem item) async {
    try {
      final file = await repo.getVideoFile(item);
      if (file == null || _disposed) return null;

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (_disposed) {
        // disposeAll() ran while this fetch was in flight — don't let a
        // controller into a dead manager's cache; it would never be
        // disposed and could still be played.
        await controller.dispose();
        return null;
      }
      await controller.setLooping(false);
      await controller.setVolume(0);
      _cache[item.id] = controller;
      return controller;
    } catch (_) {
      // A codec/corrupt-file/init failure must not leak whatever partial
      // controller state was created, nor strand the caller on a never-
      // completing future.
      return null;
    }
  }

  void trimTo(List<String> keepIds) {
    final toRemove = _cache.keys.where((id) => !keepIds.contains(id)).toList();
    for (final id in toRemove) {
      _cache.remove(id)?.dispose();
    }
  }

  Future<void> preloadNeighbors(List<MediaItem> items, int currentIndex) async {
    final ids = neighborIds(items, currentIndex);
    trimTo(ids);
    for (final id in ids) {
      final item = items.firstWhere((i) => i.id == id);
      await ensureController(item);
    }
  }

  void disposeAll() {
    _disposed = true;
    for (final c in _cache.values) {
      c.dispose();
    }
    _cache.clear();
  }
}
