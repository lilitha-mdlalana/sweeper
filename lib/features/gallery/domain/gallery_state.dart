import 'media_item.dart';
import 'swipe_action.dart';

class GalleryState {
  final List<MediaItem> queue;
  final int currentIndex;
  final MediaItem? lastActedItem;
  final SwipeAction? lastAction;
  final int totalReviewed;
  final int totalMarkedForDeletion;
  final bool isLoading;
  final bool hasMorePages;
  final int nextPage;

  /// Non-null when a background page fetch failed. The UI surfaces this to the
  /// user instead of dead-ending on a blank screen.
  final String? loadError;

  const GalleryState({
    required this.queue,
    required this.currentIndex,
    required this.lastActedItem,
    required this.lastAction,
    required this.totalReviewed,
    required this.totalMarkedForDeletion,
    required this.isLoading,
    required this.hasMorePages,
    required this.nextPage,
    this.loadError,
  });

  factory GalleryState.initial() => const GalleryState(
        queue: [],
        currentIndex: 0,
        lastActedItem: null,
        lastAction: null,
        totalReviewed: 0,
        totalMarkedForDeletion: 0,
        isLoading: false,
        hasMorePages: true,
        nextPage: 0,
        loadError: null,
      );

  MediaItem? get currentItem =>
      currentIndex < queue.length ? queue[currentIndex] : null;

  bool get isDone => currentIndex >= queue.length && !hasMorePages;

  bool get isEmpty => queue.isEmpty && !hasMorePages && !isLoading;

  int get remaining => queue.length - currentIndex;

  GalleryState copyWith({
    List<MediaItem>? queue,
    int? currentIndex,
    MediaItem? lastActedItem,
    SwipeAction? lastAction,
    int? totalReviewed,
    int? totalMarkedForDeletion,
    bool? isLoading,
    bool? hasMorePages,
    int? nextPage,
    String? loadError,
    bool clearLastAction = false,
    bool clearLoadError = false,
  }) {
    return GalleryState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      lastActedItem: clearLastAction ? null : (lastActedItem ?? this.lastActedItem),
      lastAction: clearLastAction ? null : (lastAction ?? this.lastAction),
      totalReviewed: totalReviewed ?? this.totalReviewed,
      totalMarkedForDeletion: totalMarkedForDeletion ?? this.totalMarkedForDeletion,
      isLoading: isLoading ?? this.isLoading,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      nextPage: nextPage ?? this.nextPage,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }

  GalleryState advance({required MediaItem item, required SwipeAction action}) {
    return copyWith(
      currentIndex: currentIndex + 1,
      lastActedItem: item,
      lastAction: action,
      totalReviewed: totalReviewed + 1,
      totalMarkedForDeletion:
          totalMarkedForDeletion + (action == SwipeAction.delete ? 1 : 0),
    );
  }

  GalleryState undoLast() {
    if (lastAction == null || currentIndex == 0) return this;
    final wasDelete = lastAction == SwipeAction.delete;
    return copyWith(
      currentIndex: currentIndex - 1,
      totalReviewed: totalReviewed - 1,
      totalMarkedForDeletion: totalMarkedForDeletion - (wasDelete ? 1 : 0),
      clearLastAction: true,
    );
  }
}
