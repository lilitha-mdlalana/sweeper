import '../../gallery/domain/media_item.dart';

class DeletionQueue {
  final List<MediaItem> items;

  const DeletionQueue({this.items = const []});

  int get length => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Adds [item] unless an item with the same id is already queued, so a
  /// double-add (e.g. swipe, undo, re-swipe races) can't duplicate a tile.
  DeletionQueue add(MediaItem item) => items.any((i) => i.id == item.id)
      ? this
      : DeletionQueue(items: [...items, item]);

  DeletionQueue removeById(String id) =>
      DeletionQueue(items: items.where((i) => i.id != id).toList());

  DeletionQueue clear() => const DeletionQueue();
}
