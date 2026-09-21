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

/// Builds the native query ordering for [sort].
///
/// The ordering has to be pushed down into the MediaStore / PHFetch query
/// itself: reversing a fetched page client-side would only reverse the newest
/// 60 assets among themselves, never reaching the genuinely oldest ones.
FilterOptionGroup filterOptionGroupForSort(SortOrder sort) => FilterOptionGroup(
      orders: [
        OrderOption(
          type: OrderOptionType.createDate,
          asc: sort == SortOrder.oldestFirst,
        ),
      ],
    );

class PhotoManagerRepository implements MediaRepository {
  final ThumbnailCache _thumbnailCache = ThumbnailCache();
  final Map<SortOrder, AssetPathEntity> _allPhotosPathBySort = {};

  Future<AssetPathEntity> _getAllPhotosPath(SortOrder sort) async {
    final cached = _allPhotosPathBySort[sort];
    if (cached != null) return cached;
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: filterOptionGroupForSort(sort),
    );
    if (paths.isEmpty) {
      throw StateError('No photo albums available on this device.');
    }
    _allPhotosPathBySort[sort] = paths.first;
    return paths.first;
  }

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    final path = await _getAllPhotosPath(sort);
    final total = await path.assetCountAsync;
    final assets = await path.getAssetListPaged(page: page, size: pageSize);

    final items = assets.map(mapAssetToMediaItem).toList();

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
