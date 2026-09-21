import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/photo_manager_repository.dart';
import '../domain/media_repository.dart';
import '../domain/gallery_state.dart';
import '../domain/swipe_action.dart';
import '../../settings/presentation/settings_providers.dart';

const int kPageSize = 60;

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return PhotoManagerRepository();
});

/// The swipe-event bus lives in its own provider rather than on
/// [GalleryNotifier] so that invalidating [galleryProvider] (what "Start again"
/// does) neither closes the controller nor severs existing listeners. Riverpod
/// reuses the same notifier instance across an invalidate — only `build()`
/// re-runs — so a controller owned by the notifier and closed from a
/// `build()`-scoped `ref.onDispose` would be closed out from under a still
/// living notifier, and a controller recreated per build would leave
/// already-subscribed listeners (HomeScreen) attached to a dead stream.
final swipeEventsControllerProvider =
    Provider<StreamController<SwipeAction>>((ref) {
  final controller = StreamController<SwipeAction>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

class GalleryNotifier extends AsyncNotifier<GalleryState> {
  bool _isFetchingMore = false;

  Stream<SwipeAction> get lastSwipeEvents =>
      ref.read(swipeEventsControllerProvider).stream;

  @override
  Future<GalleryState> build() async {
    final repo = ref.read(mediaRepositoryProvider);
    final settings = await ref.read(settingsProvider.future);
    final page = await repo.getMedia(page: 0, pageSize: kPageSize, sort: settings.sortOrder);
    return GalleryState.initial().copyWith(
      queue: page.items,
      hasMorePages: page.hasMore,
      nextPage: 1,
    );
  }

  Future<void> swipe(SwipeAction action) async {
    final current = state.value;
    if (current == null || current.currentItem == null) return;
    state = AsyncData(current.advance(item: current.currentItem!, action: action));
    ref.read(swipeEventsControllerProvider).add(action);
    await loadMoreIfNeeded();
  }

  void undo() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.undoLast());
  }

  Future<void> loadMoreIfNeeded() async {
    if (_isFetchingMore) return;

    final current = state.value;
    if (current == null || !current.hasMorePages) return;
    if (current.remaining > 10) return;

    _isFetchingMore = true;
    try {
      final repo = ref.read(mediaRepositoryProvider);
      final settings = await ref.read(settingsProvider.future);
      final page = await repo.getMedia(
        page: current.nextPage,
        pageSize: kPageSize,
        sort: settings.sortOrder,
      );
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(
        queue: [...latest.queue, ...page.items],
        hasMorePages: page.hasMore,
        nextPage: latest.nextPage + 1,
        clearLoadError: true,
      ));
    } catch (e) {
      // A failed page fetch must not strand the user on a blank, inert screen:
      // stop paginating so the session can reach a Done state, and record the
      // error so the UI can tell the user what happened.
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(
        hasMorePages: false,
        loadError: 'Could not load more photos: $e',
      ));
    } finally {
      _isFetchingMore = false;
    }
  }
}

final galleryProvider = AsyncNotifierProvider<GalleryNotifier, GalleryState>(
  GalleryNotifier.new,
);
