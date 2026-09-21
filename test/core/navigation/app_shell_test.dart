import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweeper/core/navigation/app_shell.dart';
import 'package:sweeper/core/theme/app_colors.dart';
import 'package:sweeper/core/theme/app_theme.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';
import 'package:sweeper/features/deletion/presentation/deletion_providers.dart';

class _FakeRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    if (page > 0) return MediaPage(items: [], hasMore: false);
    return MediaPage(
      items: List.generate(
        3,
        (i) => MediaItem(
          id: 'id$i',
          dateTaken: DateTime(2024, 1, 1),
          sizeBytes: 1000,
          width: 100,
          height: 100,
        ),
      ),
      hasMore: false,
    );
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AppShell shows Home tab by default and switches to Settings on tap',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(_FakeRepository())],
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
  });

  testWidgets('AppShell NavigationBar resolves to AppColors.navBackground via AppTheme.light',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mediaRepositoryProvider.overrideWithValue(_FakeRepository())],
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(NavigationBar));
    final resolvedBackgroundColor = NavigationBarTheme.of(context).backgroundColor;

    expect(resolvedBackgroundColor, AppColors.navBackground);
  });

  testWidgets('Review tab shows a badge with the deletion queue count', (tester) async {
    final container = ProviderContainer(
      overrides: [mediaRepositoryProvider.overrideWithValue(_FakeRepository())],
    );
    addTearDown(container.dispose);
    container.read(deletionQueueProvider.notifier).add(
      MediaItem(id: 'a', dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1),
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets);
  });
}
