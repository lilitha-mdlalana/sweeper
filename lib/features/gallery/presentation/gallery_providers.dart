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

class GalleryNotifier extends AsyncNotifier<GalleryState> {
  bool _isFetchingMore = false;
  final _swipeEventsController = StreamController<SwipeAction>.broadcast();
  Stream<SwipeAction> get lastSwipeEvents => _swipeEventsController.stream;

  @override
  Future<GalleryState> build() async {
    ref.onDispose(_swipeEventsController.close);
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
    _swipeEventsController.add(action);
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
      ));
    } finally {
      _isFetchingMore = false;
    }
  }
}

final galleryProvider = AsyncNotifierProvider<GalleryNotifier, GalleryState>(
  GalleryNotifier.new,
);
