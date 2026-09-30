import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';
import '../../gallery/domain/sort_order.dart';
import '../../gallery/presentation/gallery_providers.dart';
import '../../video_cleaner/presentation/video_cleaner_providers.dart';

export '../domain/app_settings.dart';

const _sortOrderKey = 'sweep.sortOrder';
const _confirmBeforeDeleteKey = 'sweep.confirmBeforeDelete';
const _selectedAlbumNameKey = 'sweep.selectedAlbumName';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final sortOrderName = prefs.getString(_sortOrderKey);
    final sortOrder = SortOrder.values.firstWhere(
      (o) => o.name == sortOrderName,
      orElse: () => SortOrder.newestFirst,
    );
    final confirmBeforeDelete = prefs.getBool(_confirmBeforeDeleteKey) ?? true;
    final selectedAlbumName = prefs.getString(_selectedAlbumNameKey);
    return AppSettings(
      sortOrder: sortOrder,
      confirmBeforeDelete: confirmBeforeDelete,
      selectedAlbumName: selectedAlbumName,
    );
  }

  Future<void> setSortOrder(SortOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOrderKey, order.name);
    state = AsyncData((state.value ?? const AppSettings()).copyWith(sortOrder: order));
    _restartQueues();
  }

  Future<void> setConfirmBeforeDelete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_confirmBeforeDeleteKey, value);
    state = AsyncData((state.value ?? const AppSettings()).copyWith(confirmBeforeDelete: value));
  }

  /// Pass null to select "All Photos & Videos".
  Future<void> setSelectedAlbum(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_selectedAlbumNameKey);
    } else {
      await prefs.setString(_selectedAlbumNameKey, name);
    }
    state = AsyncData((state.value ?? const AppSettings()).copyWith(
      selectedAlbumName: name,
      clearSelectedAlbumName: name == null,
    ));
    _restartQueues();
  }

  /// Neither queue notifier watches settings reactively (each only reads it
  /// once in build()), so a sort/album change mid-session needs an explicit
  /// invalidate to actually take effect instead of silently continuing to
  /// page through the old album/order.
  void _restartQueues() {
    ref.invalidate(galleryProvider);
    ref.invalidate(videoQueueProvider);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
