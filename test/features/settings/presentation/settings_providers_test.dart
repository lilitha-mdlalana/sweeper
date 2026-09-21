import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweeper/features/settings/presentation/settings_providers.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('setSortOrder and setConfirmBeforeDelete update state and persist', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).setSortOrder(SortOrder.oldestFirst);
    expect(container.read(settingsProvider).value?.sortOrder, SortOrder.oldestFirst);

    await container.read(settingsProvider.notifier).setConfirmBeforeDelete(false);
    expect(container.read(settingsProvider).value?.confirmBeforeDelete, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sweep.sortOrder'), 'oldestFirst');
    expect(prefs.getBool('sweep.confirmBeforeDelete'), isFalse);
  });
}
