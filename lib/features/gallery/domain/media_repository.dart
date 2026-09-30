import 'dart:io';
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
    String? albumName,
  });

  Future<MediaPage> getVideoMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
    String? albumName,
  });

  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300});

  Future<Uint8List?> getOriginalBytes(MediaItem item);

  /// A playback-ready [File] for [item], used by video playback instead of
  /// [getOriginalBytes] — loading a whole video into memory is unacceptable
  /// at GB scale.
  Future<File?> getVideoFile(MediaItem item);

  Future<DeleteResult> deleteMedia(List<MediaItem> items);
}
