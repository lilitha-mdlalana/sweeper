import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/domain/gallery_state.dart';
import 'package:sweeper/features/gallery/domain/swipe_action.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

MediaItem _item(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
    );

void main() {
  test('advance moves currentIndex forward and records the action', () {
    final state = GalleryState.initial().copyWith(queue: [_item('a'), _item('b')]);

    final next = state.advance(item: _item('a'), action: SwipeAction.delete);

    expect(next.currentIndex, 1);
    expect(next.lastAction, SwipeAction.delete);
    expect(next.lastActedItem!.id, 'a');
    expect(next.totalReviewed, 1);
    expect(next.totalMarkedForDeletion, 1);
    expect(next.currentItem!.id, 'b');
  });

  test('undoLast steps currentIndex back and clears lastAction', () {
    final state = GalleryState.initial()
        .copyWith(queue: [_item('a'), _item('b')])
        .advance(item: _item('a'), action: SwipeAction.delete);

    final undone = state.undoLast();

    expect(undone.currentIndex, 0);
    expect(undone.lastAction, isNull);
    expect(undone.totalReviewed, 0);
    expect(undone.totalMarkedForDeletion, 0);
  });

  test('undoLast on fresh state is a no-op', () {
    final state = GalleryState.initial().copyWith(queue: [_item('a')]);
    final undone = state.undoLast();
    expect(undone.currentIndex, 0);
  });

  test('isDone is true once currentIndex reaches queue length', () {
    final state = GalleryState.initial()
        .copyWith(queue: [_item('a')])
        .advance(item: _item('a'), action: SwipeAction.keep);
    expect(state.isDone, isTrue);
    expect(state.currentItem, isNull);
  });
}
