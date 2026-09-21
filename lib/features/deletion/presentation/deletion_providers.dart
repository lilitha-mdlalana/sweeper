import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/deletion_queue.dart';
import '../../gallery/domain/media_item.dart';

class DeletionQueueNotifier extends Notifier<DeletionQueue> {
  @override
  DeletionQueue build() => const DeletionQueue();

  void add(MediaItem item) => state = state.add(item);
  void removeById(String id) => state = state.removeById(id);
  void restoreAll() => state = state.clear();
  void clear() => state = state.clear();
}

final deletionQueueProvider = NotifierProvider<DeletionQueueNotifier, DeletionQueue>(
  DeletionQueueNotifier.new,
);
