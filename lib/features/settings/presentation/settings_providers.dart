import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';
import '../../gallery/domain/sort_order.dart';

export '../domain/app_settings.dart';

const _sortOrderKey = 'sweep.sortOrder';
const _confirmBeforeDeleteKey = 'sweep.confirmBeforeDelete';

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
    return AppSettings(sortOrder: sortOrder, confirmBeforeDelete: confirmBeforeDelete);
  }

  Future<void> setSortOrder(SortOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOrderKey, order.name);
    state = AsyncData((state.value ?? const AppSettings()).copyWith(sortOrder: order));
  }

  Future<void> setConfirmBeforeDelete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_confirmBeforeDeleteKey, value);
    state = AsyncData((state.value ?? const AppSettings()).copyWith(confirmBeforeDelete: value));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
