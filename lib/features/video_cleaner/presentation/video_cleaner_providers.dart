import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../gallery/domain/media_item.dart';
import '../../gallery/presentation/gallery_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../deletion/presentation/deletion_providers.dart';
import '../domain/video_queue_state.dart';

const int kVideoPageSize = 40;

class VideoQueueNotifier extends AsyncNotifier<VideoQueueState> {
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

  void decide(String id, VideoDecision decision) {
    final current = state.value;
    if (current == null) return;
    MediaItem? item;
    for (final i in current.items) {
      if (i.id == id) {
        item = i;
        break;
      }
    }
    if (item == null) return;

    state = AsyncData(current.decide(id, decision));

    if (decision == VideoDecision.delete) {
      ref.read(deletionQueueProvider.notifier).add(item);
    }
  }

  void undo() {
    final current = state.value;
    if (current == null || current.history.isEmpty) return;
    final last = current.history.last;
    final wasDelete = current.decisions[last.id] == VideoDecision.delete;

    state = AsyncData(current.undo());

    if (wasDelete) {
      ref.read(deletionQueueProvider.notifier).removeById(last.id);
    }
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

final videoQueueProvider = AsyncNotifierProvider<VideoQueueNotifier, VideoQueueState>(
  VideoQueueNotifier.new,
);
