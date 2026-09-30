import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../gallery/domain/sort_order.dart';
import 'settings_providers.dart';
import 'privacy_screen.dart';
import 'album_picker_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value;

    return Scaffold(
      key: const Key('settings-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text('Settings', style: AppTextStyles.display(size: 32)),
            const SizedBox(height: 18),
            _SectionLabel('Cleaning'),
            const SizedBox(height: 8),
            _Card(children: [
              InkWell(
                onTap: () => showAlbumPickerSheet(context),
                child: _Row(
                  label: 'Album',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: _Badge(settings?.selectedAlbumName ?? 'All Photos & Videos'),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.rowDivider),
              _Row(
                label: 'Sort order',
                trailing: settings == null
                    ? const SizedBox.shrink()
                    : _SortToggle(
                        current: settings.sortOrder,
                        onChanged: (order) =>
                            ref.read(settingsProvider.notifier).setSortOrder(order),
                      ),
              ),
              const Divider(height: 1, color: AppColors.rowDivider),
              _Row(
                label: 'Confirm before deleting',
                subtitle: 'Ask before anything is removed for good',
                trailing: Switch(
                  value: settings?.confirmBeforeDelete ?? true,
                  onChanged: (value) =>
                      ref.read(settingsProvider.notifier).setConfirmBeforeDelete(value),
                ),
              ),
            ]),
            const SizedBox(height: 22),
            _SectionLabel('Gestures'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: const [
                _GestureTile(label: 'Delete', subtitle: 'Swipe left'),
                _GestureTile(label: 'Keep', subtitle: 'Swipe right'),
                _GestureTile(label: 'Favourite', subtitle: 'Swipe up'),
                _GestureTile(label: 'Skip', subtitle: 'Swipe down'),
              ],
            ),
            const SizedBox(height: 22),
            _SectionLabel('About'),
            const SizedBox(height: 8),
            _Card(children: [
              ListTile(
                title: const Text('Privacy'),
                subtitle: const Text('Nothing leaves your phone'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
              const Divider(height: 1, color: AppColors.rowDivider),
              // No About destination exists, so no chevron: the row must not
              // promise navigation it doesn't have.
              const ListTile(
                title: Text('About Sweep'),
                subtitle: Text('A private gallery cleaner'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderMedium),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(children: children),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget trailing;
  const _Row({required this.label, this.subtitle, required this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: AppTextStyles.bodySecondary(size: 13)),
              ],
            ),
          ),
          trailing,
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(16)),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: Colors.white),
        ),
      );
}

class _SortToggle extends StatelessWidget {
  final SortOrder current;
  final ValueChanged<SortOrder> onChanged;
  const _SortToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _SortButton(
        label: 'Newest',
        selected: current == SortOrder.newestFirst,
        onTap: () => onChanged(SortOrder.newestFirst),
      ),
      _SortButton(
        label: 'Oldest',
        selected: current == SortOrder.oldestFirst,
        onTap: () => onChanged(SortOrder.oldestFirst),
      ),
      _SortButton(
        label: 'Random',
        selected: current == SortOrder.random,
        onTap: () => onChanged(SortOrder.random),
      ),
    ]);
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: selected ? AppColors.textPrimary : Colors.transparent,
          foregroundColor: selected ? Colors.white : AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _GestureTile extends StatelessWidget {
  final String label;
  final String subtitle;
  const _GestureTile({required this.label, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderMedium),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
                Text(subtitle, style: AppTextStyles.bodySecondary(size: 13)),
              ],
            ),
          ),
        ]),
      );
}
