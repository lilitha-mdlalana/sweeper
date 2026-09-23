import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/video_cleaner/domain/video_queue_state.dart';

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
  test('initial state has no items and position 0', () {
    final state = VideoQueueState.initial();
    expect(state.items, isEmpty);
    expect(state.currentPageIndex, 0);
    expect(state.totalCount, 0);
    expect(state.reviewedCount, 0);
    expect(state.markedForDeletionCount, 0);
    expect(state.storageToReclaimBytes, 0);
  });

  test('totalCount reflects the loaded items list', () {
    final state = VideoQueueState.initial()
        .copyWith(items: [_video('a'), _video('b'), _video('c')]);
    expect(state.totalCount, 3);
  });

  test('decide(delete) marks the item and counts it toward storageToReclaimBytes', () {
    final state = VideoQueueState.initial().copyWith(
      items: [_video('a', sizeBytes: 2000), _video('b', sizeBytes: 3000)],
    );

    final next = state.decide('a', VideoDecision.delete);

    expect(next.decisions['a'], VideoDecision.delete);
    expect(next.markedForDeletionCount, 1);
    expect(next.storageToReclaimBytes, 2000);
    expect(next.reviewedCount, 1);
  });

  test('decide(keep) marks the item without affecting storageToReclaimBytes', () {
    final state = VideoQueueState.initial().copyWith(items: [_video('a')]);

    final next = state.decide('a', VideoDecision.keep);

    expect(next.decisions['a'], VideoDecision.keep);
    expect(next.markedForDeletionCount, 0);
    expect(next.reviewedCount, 1);
  });

  test('decide pushes a history entry recording the previous decision', () {
    final state = VideoQueueState.initial().copyWith(items: [_video('a')]);

    final afterKeep = state.decide('a', VideoDecision.keep);
    final afterDelete = afterKeep.decide('a', VideoDecision.delete);

    expect(afterDelete.history.last.id, 'a');
    expect(afterDelete.history.last.previous, VideoDecision.keep);
  });

  test('undo restores the previous decision and pops history', () {
    final state = VideoQueueState.initial().copyWith(items: [_video('a')]);
    final decided = state.decide('a', VideoDecision.delete);

    final undone = decided.undo();

    expect(undone.decisions['a'], VideoDecision.undecided);
    expect(undone.history, isEmpty);
    expect(undone.reviewedCount, 0);
    expect(undone.storageToReclaimBytes, 0);
  });

  test('undo on empty history is a no-op', () {
    final state = VideoQueueState.initial().copyWith(items: [_video('a')]);
    final undone = state.undo();
    expect(undone.decisions, isEmpty);
  });

  test('recordImplicitKeepIfUndecided sets keep only when still undecided', () {
    final state = VideoQueueState.initial().copyWith(items: [_video('a'), _video('b')]);

    final afterImplicit = state.recordImplicitKeepIfUndecided('a');
    expect(afterImplicit.decisions['a'], VideoDecision.keep);

    // Already decided explicitly as delete: implicit-keep must not override it.
    final explicitlyDeleted = state.decide('a', VideoDecision.delete);
    final afterImplicitOnDecided = explicitlyDeleted.recordImplicitKeepIfUndecided('a');
    expect(afterImplicitOnDecided.decisions['a'], VideoDecision.delete);
  });

  test('isEmpty is true only once loaded with zero items and no more pages', () {
    final loading = VideoQueueState.initial().copyWith(isLoading: true);
    expect(loading.isEmpty, isFalse);

    final stillPaging = VideoQueueState.initial().copyWith(hasMorePages: true);
    expect(stillPaging.isEmpty, isFalse);

    final empty = VideoQueueState.initial().copyWith(hasMorePages: false);
    expect(empty.isEmpty, isTrue);
  });

  test('isSessionComplete is true once every loaded item has a decision and no more pages', () {
    final state = VideoQueueState.initial().copyWith(
      items: [_video('a'), _video('b')],
      hasMorePages: false,
    );
    expect(state.isSessionComplete, isFalse);

    final oneReviewed = state.decide('a', VideoDecision.keep);
    expect(oneReviewed.isSessionComplete, isFalse);

    final allReviewed = oneReviewed.decide('b', VideoDecision.delete);
    expect(allReviewed.isSessionComplete, isTrue);
  });

  test('isSessionComplete is false while more pages remain, even if all loaded items are decided', () {
    final state = VideoQueueState.initial().copyWith(
      items: [_video('a')],
      hasMorePages: true,
    );
    final decided = state.decide('a', VideoDecision.keep);
    expect(decided.isSessionComplete, isFalse);
  });

  test('currentItem returns the item at currentPageIndex or null past the end', () {
    final state = VideoQueueState.initial().copyWith(items: [_video('a'), _video('b')]);
    expect(state.currentItem!.id, 'a');

    final atEnd = state.copyWith(currentPageIndex: 2);
    expect(atEnd.currentItem, isNull);
  });
}
