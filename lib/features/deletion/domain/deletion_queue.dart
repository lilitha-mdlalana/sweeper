import '../../gallery/domain/media_item.dart';

class DeletionQueue {
  final List<MediaItem> items;

  const DeletionQueue({this.items = const []});

  int get length => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  DeletionQueue add(MediaItem item) => DeletionQueue(items: [...items, item]);

  DeletionQueue removeById(String id) =>
      DeletionQueue(items: items.where((i) => i.id != id).toList());

  DeletionQueue clear() => const DeletionQueue();
}
