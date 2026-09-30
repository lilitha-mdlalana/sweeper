import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../domain/album_option.dart';

/// Albums fetched with RequestType.common can contain both photos and
/// videos, giving one shared list to pick from regardless of which cleaner
/// the selection will end up feeding.
final albumListProvider = FutureProvider<List<AlbumOption>>((ref) async {
  final paths = await PhotoManager.getAssetPathList(
    type: RequestType.common,
    onlyAll: false,
  );
  final options = await Future.wait(paths.map((p) async {
    final count = await p.assetCountAsync;
    return AlbumOption(name: p.name, assetCount: count);
  }));
  return options;
});
