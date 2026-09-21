import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../domain/media_repository.dart';
import '../domain/media_item.dart';
import '../domain/media_page.dart';
import '../domain/sort_order.dart';
import '../domain/delete_result.dart';
import 'thumbnail_cache.dart';

MediaItem mapAssetToMediaItem(AssetEntity asset) => MediaItem(
      id: asset.id,
      dateTaken: asset.createDateTime,
      sizeBytes: 0, // photo_manager doesn't expose file size synchronously; left 0 for MVP list view
      width: asset.width,
      height: asset.height,
      type: asset.type == AssetType.video ? MediaType.video : MediaType.photo,
    );

DeleteResult mapDeleteIdsToResult({
  required List<String> requestedIds,
  required List<String> deletedIds,
}) {
  final deletedSet = deletedIds.toSet();
  return DeleteResult(
    deletedIds: requestedIds.where(deletedSet.contains).toList(),
    failedIds: requestedIds.where((id) => !deletedSet.contains(id)).toList(),
  );
}

class PhotoManagerRepository implements MediaRepository {
  final ThumbnailCache _thumbnailCache = ThumbnailCache();
  AssetPathEntity? _allPhotosPath;

  Future<AssetPathEntity> _getAllPhotosPath() async {
    if (_allPhotosPath != null) return _allPhotosPath!;
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      throw StateError('No photo albums available on this device.');
    }
    _allPhotosPath = paths.first;
    return _allPhotosPath!;
  }

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    final path = await _getAllPhotosPath();
    final total = await path.assetCountAsync;
    final assets = await path.getAssetListPaged(page: page, size: pageSize);

    var items = assets.map(mapAssetToMediaItem).toList();
    if (sort == SortOrder.oldestFirst) {
      items = items.reversed.toList();
    }

    final loadedSoFar = (page + 1) * pageSize;
    return MediaPage(items: items, hasMore: loadedSoFar < total);
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async {
    final cached = _thumbnailCache.get(item.id);
    if (cached != null) return cached;

    final asset = await AssetEntity.fromId(item.id);
    if (asset == null) return null;
    final bytes = await asset.thumbnailDataWithSize(ThumbnailSize.square(size));
    if (bytes != null) _thumbnailCache.put(item.id, bytes);
    return bytes;
  }

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async {
    final asset = await AssetEntity.fromId(item.id);
    if (asset == null) return null;
    return asset.originBytes;
  }

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async {
    final ids = items.map((i) => i.id).toList();
    final deletedIds = await PhotoManager.editor.deleteWithIds(ids);
    return mapDeleteIdsToResult(requestedIds: ids, deletedIds: deletedIds);
  }
}
