import 'dart:io';
import 'dart:math';
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
      // asset.duration is seconds; 0 for photos.
      durationMs: asset.duration * 1000,
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
///
/// [SortOrder.random] has no native equivalent, so it uses the same
/// underlying order as [SortOrder.newestFirst] for the base fetch — the
/// actual randomization happens client-side in [PhotoManagerRepository.getShuffledAssets].
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
  final Map<(SortOrder, RequestType, String?), AssetPathEntity> _pathByKey = {};

  /// Resolves the album to read from for [type].
  ///
  /// When [albumName] is null, or no album matching it exists for this
  /// [type] (e.g. an album with photos but no videos, selected while using
  /// the video cleaner), falls back to the device's synthetic "all" album —
  /// the picker surfaces per-type asset counts so users can see up front
  /// when a pick won't apply to a given type.
  Future<AssetPathEntity> _getAllMediaPath(
    SortOrder sort,
    RequestType type,
    String? albumName,
  ) async {
    final key = (sort, type, albumName);
    final cached = _pathByKey[key];
    if (cached != null) return cached;

    final filterOption = filterOptionGroupForSort(sort);

    if (albumName != null) {
      final paths = await PhotoManager.getAssetPathList(
        type: type,
        onlyAll: false,
        filterOption: filterOption,
      );
      for (final path in paths) {
        if (path.name == albumName) {
          _pathByKey[key] = path;
          return path;
        }
      }
      // No matching album for this type — fall through to "all".
    }

    final paths = await PhotoManager.getAssetPathList(
      type: type,
      onlyAll: true,
      filterOption: filterOption,
    );
    if (paths.isEmpty) {
      throw StateError('No media albums available on this device.');
    }
    _pathByKey[key] = paths.first;
    return paths.first;
  }

  final Map<(RequestType, String?), List<AssetEntity>> _shuffledByKey = {};

  /// photo_manager has no native random ordering and no batch by-id fetch,
  /// so a true (non-chunky) random order means fetching the whole album
  /// once and shuffling client-side, then paging by slicing that fixed list.
  ///
  /// Re-shuffled whenever [page] is 0 — which only happens once per queue
  /// notifier's build(), i.e. once per screen visit — so re-entering a
  /// cleaner gets a fresh order, while pages within one visit stay
  /// consistent (no skipped/duplicated items).
  Future<List<AssetEntity>> _getShuffledAssets({
    required RequestType type,
    required String? albumName,
    required int page,
  }) async {
    final key = (type, albumName);
    if (page == 0) {
      final path = await _getAllMediaPath(SortOrder.random, type, albumName);
      final total = await path.assetCountAsync;
      final assets = await path.getAssetListRange(start: 0, end: total);
      final shuffled = List.of(assets)..shuffle(Random());
      _shuffledByKey[key] = shuffled;
      return shuffled;
    }
    return _shuffledByKey[key] ?? await _getShuffledAssets(type: type, albumName: albumName, page: 0);
  }

  Future<MediaPage> _getMediaPage({
    required int page,
    required int pageSize,
    required SortOrder sort,
    required RequestType type,
    String? albumName,
  }) async {
    if (sort == SortOrder.random) {
      final assets = await _getShuffledAssets(type: type, albumName: albumName, page: page);
      final start = page * pageSize;
      final end = (start + pageSize).clamp(0, assets.length);
      final slice = start < assets.length ? assets.sublist(start, end) : const <AssetEntity>[];
      return MediaPage(items: slice.map(mapAssetToMediaItem).toList(), hasMore: end < assets.length);
    }

    final path = await _getAllMediaPath(sort, type, albumName);
    final total = await path.assetCountAsync;
    final assets = await path.getAssetListPaged(page: page, size: pageSize);

    final items = assets.map(mapAssetToMediaItem).toList();

    final loadedSoFar = (page + 1) * pageSize;
    return MediaPage(items: items, hasMore: loadedSoFar < total);
  }

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
    String? albumName,
  }) =>
      _getMediaPage(
        page: page,
        pageSize: pageSize,
        sort: sort,
        type: RequestType.image,
        albumName: albumName,
      );

  @override
  Future<MediaPage> getVideoMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
    String? albumName,
  }) =>
      _getMediaPage(
        page: page,
        pageSize: pageSize,
        sort: sort,
        type: RequestType.video,
        albumName: albumName,
      );

  @override
  Future<File?> getVideoFile(MediaItem item) async {
    final asset = await AssetEntity.fromId(item.id);
    return asset?.file;
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
