import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/deletion/presentation/deletion_providers.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

MediaItem _item(String id) => MediaItem(
      id: id, dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1,
    );

void main() {
  test('add/removeById/restoreAll manage the queue', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(deletionQueueProvider.notifier);

    notifier.add(_item('a'));
    notifier.add(_item('b'));
    expect(container.read(deletionQueueProvider).length, 2);

    notifier.removeById('a');
    expect(container.read(deletionQueueProvider).length, 1);

    notifier.clear();
    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });
}
