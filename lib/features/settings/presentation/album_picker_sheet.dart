import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../gallery/presentation/album_providers.dart';
import 'settings_providers.dart';

Future<void> showAlbumPickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AlbumPickerSheet(),
  );
}

class _AlbumPickerSheet extends ConsumerWidget {
  const _AlbumPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumListProvider);
    final selected = ref.watch(settingsProvider).value?.selectedAlbumName;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Album', style: AppTextStyles.display(size: 20)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _AlbumRow(
                    label: 'All Photos & Videos',
                    subtitle: null,
                    selected: selected == null,
                    onTap: () {
                      ref.read(settingsProvider.notifier).setSelectedAlbum(null);
                      Navigator.of(context).pop();
                    },
                  ),
                  const Divider(height: 1, color: AppColors.rowDivider),
                  switch (albumsAsync) {
                    AsyncData(:final value) => Column(
                        children: [
                          for (final album in value) ...[
                            _AlbumRow(
                              label: album.name,
                              subtitle: '${album.assetCount} items',
                              selected: selected == album.name,
                              onTap: () {
                                ref.read(settingsProvider.notifier).setSelectedAlbum(album.name);
                                Navigator.of(context).pop();
                              },
                            ),
                            const Divider(height: 1, color: AppColors.rowDivider),
                          ],
                        ],
                      ),
                    AsyncError() => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Could not load albums.'),
                      ),
                    _ => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AlbumRow({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label, style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle!, style: AppTextStyles.bodySecondary(size: 13)),
        trailing: selected ? const Icon(Icons.check, color: AppColors.textPrimary) : null,
        onTap: onTap,
      );
}
