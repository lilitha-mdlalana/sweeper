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

  VideoControllerManager(this.repo);

  VideoPlayerController? controllerFor(String id) => _cache[id];

  Future<VideoPlayerController?> ensureController(MediaItem item) async {
    final existing = _cache[item.id];
    if (existing != null) return existing;

    final file = await repo.getVideoFile(item);
    if (file == null) return null;

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    await controller.setLooping(false);
    await controller.setVolume(0);
    _cache[item.id] = controller;
    return controller;
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
    for (final c in _cache.values) {
      c.dispose();
    }
    _cache.clear();
  }
}
