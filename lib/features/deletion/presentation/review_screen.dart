import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../gallery/presentation/gallery_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import 'confirm_delete_dialog.dart';
import 'deletion_providers.dart';
import 'media_preview_screen.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(deletionQueueProvider);
    final repo = ref.read(mediaRepositoryProvider);

    return Scaffold(
      key: const Key('review-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Items to delete', style: AppTextStyles.display(size: 28)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('${queue.length} items',
                        style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Tap a photo to preview it. Nothing is removed until you confirm.',
                  style: AppTextStyles.bodySecondary()),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue.items[index];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MediaPreviewScreen(item: item)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: FutureBuilder<Uint8List?>(
                                future: repo.getThumbnail(item),
                                builder: (context, snapshot) {
                                  if (snapshot.data == null) {
                                    return Container(color: AppColors.chipBackground);
                                  }
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              key: Key('remove-tile-${item.id}'),
                              icon: const Icon(Icons.close, color: Colors.white, size: 14),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                minimumSize: const Size(24, 24),
                              ),
                              onPressed: () =>
                                  ref.read(deletionQueueProvider.notifier).removeById(item.id),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.read(deletionQueueProvider.notifier).restoreAll(),
                      icon: const Icon(Icons.undo),
                      label: const Text('Restore all'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(128, 56),
                        side: const BorderSide(color: AppColors.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: queue.isEmpty
                            ? null
                            : () => _handleDeletePermanently(context, ref, queue.length),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size(0, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: const Text('Delete permanently',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeletePermanently(BuildContext context, WidgetRef ref, int count) async {
    final confirmBeforeDelete = ref.read(settingsProvider).confirmBeforeDelete;
    if (confirmBeforeDelete) {
      final confirmed = await showConfirmDeleteDialog(context, itemCount: count);
      if (confirmed != true) return;
    }

    final queue = ref.read(deletionQueueProvider);
    final repo = ref.read(mediaRepositoryProvider);
    final result = await repo.deleteMedia(queue.items);

    final notifier = ref.read(deletionQueueProvider.notifier);
    for (final id in result.deletedIds) {
      notifier.removeById(id);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.successCount} of ${result.totalCount} deleted')),
    );
  }
}
