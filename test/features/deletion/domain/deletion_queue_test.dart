import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/deletion/domain/deletion_queue.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

MediaItem _item(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
    );

void main() {
  test('add appends an item and removeById drops it by id', () {
    const empty = DeletionQueue();
    final withOne = empty.add(_item('a'));
    final withTwo = withOne.add(_item('b'));

    expect(withTwo.length, 2);

    final withOneAgain = withTwo.removeById('a');
    expect(withOneAgain.length, 1);
    expect(withOneAgain.items.first.id, 'b');
  });

  test('clear empties the queue', () {
    final queue = const DeletionQueue().add(_item('a')).clear();
    expect(queue.isEmpty, isTrue);
  });
}
