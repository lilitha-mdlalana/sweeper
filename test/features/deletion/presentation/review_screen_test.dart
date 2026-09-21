import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';
import 'package:sweeper/features/deletion/presentation/deletion_providers.dart';
import 'package:sweeper/features/settings/presentation/settings_providers.dart';
import 'package:sweeper/features/deletion/presentation/review_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NullThumbRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);
  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;
  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;
  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

/// Simulates a platform failure (e.g. PlatformException when the app is
/// backgrounded mid system-delete-dialog).
class ThrowingDeleteRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);
  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;
  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;
  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      throw PlatformException(code: 'delete_failed');
}

MediaItem _item(String id) => MediaItem(id: id, dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1);

void main() {
  testWidgets('ReviewScreen shows the item count and removes a tile on tap', (tester) async {
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(NullThumbRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(deletionQueueProvider.notifier).add(_item('a'));
    container.read(deletionQueueProvider.notifier).add(_item('b'));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReviewScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 items'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-tile-a')));
    await tester.pumpAndSettle();

    expect(find.text('1 items'), findsOneWidget);
  });

  testWidgets('Restore all clears the queue', (tester) async {
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(NullThumbRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(deletionQueueProvider.notifier).add(_item('a'));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReviewScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore all'));
    await tester.pumpAndSettle();

    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });

  testWidgets('a failed permanent delete tells the user and keeps the queue intact',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sweep.confirmBeforeDelete': false});
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(ThrowingDeleteRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(deletionQueueProvider.notifier).add(_item('a'));
    await container.read(settingsProvider.future);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReviewScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-failed-snackbar')), findsOneWidget);
    expect(find.text('Deletion failed. Nothing was removed.'), findsOneWidget);
    // Queue untouched, so the user can retry.
    expect(container.read(deletionQueueProvider).length, 1);
  });
}
