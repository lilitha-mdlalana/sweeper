// Basic smoke test for the Sweep app's root widget.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sweeper/main.dart';
import 'package:sweeper/features/settings/presentation/permission_providers.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';

class _GrantedPermissionNotifier extends PermissionStatusNotifier {
  @override
  Future<PermissionState> build() async => PermissionState.granted;
}

class _FakeRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
    String? albumName,
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
  Future<MediaPage> getVideoMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
    String? albumName,
  }) async =>
      MediaPage(items: [], hasMore: false);

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<File?> getVideoFile(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SweepApp shows the bottom nav shell with all tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionStatusProvider.overrideWith(_GrantedPermissionNotifier.new),
          mediaRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const SweepApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Review'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
