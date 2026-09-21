import 'dart:typed_data';
import 'media_item.dart';
import 'media_page.dart';
import 'sort_order.dart';
import 'delete_result.dart';

abstract class MediaRepository {
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  });

  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300});

  Future<Uint8List?> getOriginalBytes(MediaItem item);

  Future<DeleteResult> deleteMedia(List<MediaItem> items);
}
