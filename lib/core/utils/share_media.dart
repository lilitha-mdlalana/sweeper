import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/gallery/domain/media_item.dart';
import '../../features/gallery/domain/media_repository.dart';

/// Opens the platform share sheet for [item], anchored to [context]'s render
/// box — iPad/Mac need a non-null `sharePositionOrigin` for the popover,
/// everywhere else it's ignored.
Future<void> shareMediaItem(
  BuildContext context,
  MediaRepository repo,
  MediaItem item,
) async {
  final file = await repo.getShareableFile(item);
  if (file == null || !context.mounted) return;

  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

  await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
}
