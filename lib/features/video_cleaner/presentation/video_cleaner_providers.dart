import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../gallery/domain/media_item.dart';
import '../../gallery/presentation/gallery_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../deletion/presentation/deletion_providers.dart';
import '../domain/video_queue_state.dart';

const int kVideoPageSize = 40;

class VideoQueueNotifier extends AutoDisposeAsyncNotifier<VideoQueueState> {
  bool _isFetchingMore = false;

  @override
  Future<VideoQueueState> build() async {
    final repo = ref.read(mediaRepositoryProvider);
    final settings = await ref.read(settingsProvider.future);
    final page = await repo.getVideoMedia(page: 0, pageSize: kVideoPageSize, sort: settings.sortOrder);
    return VideoQueueState.initial().copyWith(
      items: page.items,
      hasMorePages: page.hasMore,
      nextPage: 1,
    );
  }

  MediaItem? _findItem(VideoQueueState state, String id) {
    for (final i in state.items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Adds/removes [item] from the shared deletion queue based on the actual
  /// before/after transition, rather than assuming the new decision alone
  /// (or which decision happened most recently) tells us what to do — that
  /// assumption breaks the moment a delete is changed to keep, redecided, or
  /// undone out of order.
  void _syncDeletionQueue(MediaItem item, {required VideoDecision before, required VideoDecision after}) {
    if (before == after) return;
    final queue = ref.read(deletionQueueProvider.notifier);
    if (after == VideoDecision.delete) {
      queue.add(item);
    } else if (before == VideoDecision.delete) {
      queue.removeById(item.id);
    }
  }

  void decide(String id, VideoDecision decision) {
    final current = state.value;
    if (current == null) return;
    final item = _findItem(current, id);
    if (item == null) return;

    final before = current.decisionFor(id);
    state = AsyncData(current.decide(id, decision));
    _syncDeletionQueue(item, before: before, after: decision);
  }

  /// Undoes the most recent decision made on [id] specifically — scoped so a
  /// snackbar's UNDO always reverses the decision it was shown for, even if
  /// the user has since decided a different video.
  void undoFor(String id) {
    final current = state.value;
    if (current == null) return;
    final item = _findItem(current, id);
    if (item == null) return;

    final entryIndex = current.history.lastIndexWhere((e) => e.id == id);
    if (entryIndex == -1) return;

    final before = current.decisionFor(id);
    final after = current.history[entryIndex].previous;
    state = AsyncData(current.undoById(id));
    _syncDeletionQueue(item, before: before, after: after);
  }

  void setCurrentPage(int index) {
    final current = state.value;
    if (current == null) return;
    final previousItem = current.currentItem;
    var next = current;
    if (previousItem != null) {
      next = next.recordImplicitKeepIfUndecided(previousItem.id);
    }
    next = next.copyWith(currentPageIndex: index);
    state = AsyncData(next);
    loadMoreIfNeeded();
  }

  Future<void> loadMoreIfNeeded() async {
    if (_isFetchingMore) return;

    final current = state.value;
    if (current == null || !current.hasMorePages) return;
    if (current.items.length - current.currentPageIndex > 10) return;

    _isFetchingMore = true;
    try {
      final repo = ref.read(mediaRepositoryProvider);
      final settings = await ref.read(settingsProvider.future);
      final page = await repo.getVideoMedia(
        page: current.nextPage,
        pageSize: kVideoPageSize,
        sort: settings.sortOrder,
      );
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(
        items: [...latest.items, ...page.items],
        hasMorePages: page.hasMore,
        nextPage: latest.nextPage + 1,
        clearLoadError: true,
      ));
    } catch (e) {
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(
        hasMorePages: false,
        loadError: 'Could not load more videos: $e',
      ));
    } finally {
      _isFetchingMore = false;
    }
  }
}

/// autoDispose: VideoCleanerScreen is pushed/popped via Navigator (it never
/// stays mounted the way the photo tab does inside AppShell's IndexedStack),
/// so each visit is intentionally a fresh session — a stale position or
/// stale decisions from a previous visit, or from videos the Review tab
/// since removed/restored/deleted, are never carried forward.
final videoQueueProvider = AutoDisposeAsyncNotifierProvider<VideoQueueNotifier, VideoQueueState>(
  VideoQueueNotifier.new,
);
