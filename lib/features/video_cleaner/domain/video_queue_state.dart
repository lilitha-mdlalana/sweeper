import '../../gallery/domain/media_item.dart';

enum VideoDecision { undecided, keep, delete }

class VideoDecisionHistoryEntry {
  final String id;
  final VideoDecision previous;
  const VideoDecisionHistoryEntry({required this.id, required this.previous});
}

class VideoQueueState {
  final List<MediaItem> items;
  final int currentPageIndex;
  final Map<String, VideoDecision> decisions;
  final bool isLoading;
  final bool hasMorePages;
  final int nextPage;
  final List<VideoDecisionHistoryEntry> history;
  final String? loadError;

  const VideoQueueState({
    required this.items,
    required this.currentPageIndex,
    required this.decisions,
    required this.isLoading,
    required this.hasMorePages,
    required this.nextPage,
    required this.history,
    this.loadError,
  });

  factory VideoQueueState.initial() => const VideoQueueState(
        items: [],
        currentPageIndex: 0,
        decisions: {},
        isLoading: false,
        hasMorePages: true,
        nextPage: 0,
        history: [],
        loadError: null,
      );

  VideoDecision decisionFor(String id) => decisions[id] ?? VideoDecision.undecided;

  int get totalCount => items.length;

  int get reviewedCount =>
      decisions.values.where((d) => d != VideoDecision.undecided).length;

  int get markedForDeletionCount =>
      decisions.values.where((d) => d == VideoDecision.delete).length;

  int get storageToReclaimBytes => items
      .where((i) => decisions[i.id] == VideoDecision.delete)
      .fold(0, (sum, i) => sum + i.sizeBytes);

  bool get isAtEnd => currentPageIndex >= items.length - 1 && !hasMorePages;

  bool get isSessionComplete =>
      totalCount > 0 && !hasMorePages && reviewedCount >= totalCount;

  bool get isEmpty => items.isEmpty && !hasMorePages && !isLoading;

  MediaItem? get currentItem =>
      currentPageIndex < items.length ? items[currentPageIndex] : null;

  VideoQueueState copyWith({
    List<MediaItem>? items,
    int? currentPageIndex,
    Map<String, VideoDecision>? decisions,
    bool? isLoading,
    bool? hasMorePages,
    int? nextPage,
    List<VideoDecisionHistoryEntry>? history,
    String? loadError,
    bool clearLoadError = false,
  }) {
    return VideoQueueState(
      items: items ?? this.items,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      decisions: decisions ?? this.decisions,
      isLoading: isLoading ?? this.isLoading,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      nextPage: nextPage ?? this.nextPage,
      history: history ?? this.history,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }

  /// Records an explicit decision, pushing the item's previous decision onto
  /// [history] so [undo] can restore it.
  VideoQueueState decide(String id, VideoDecision decision) {
    final previous = decisionFor(id);
    return copyWith(
      decisions: {...decisions, id: decision},
      history: [...history, VideoDecisionHistoryEntry(id: id, previous: previous)],
    );
  }

  /// Sets [id]'s decision to keep only if it's still undecided — paging past
  /// a video without an explicit choice defaults to keep, but must never
  /// override an explicit decision the user already made.
  VideoQueueState recordImplicitKeepIfUndecided(String id) {
    if (decisionFor(id) != VideoDecision.undecided) return this;
    return copyWith(decisions: {...decisions, id: VideoDecision.keep});
  }

  VideoQueueState undo() {
    if (history.isEmpty) return this;
    final last = history.last;
    return copyWith(
      decisions: {...decisions, last.id: last.previous},
      history: history.sublist(0, history.length - 1),
    );
  }
}
