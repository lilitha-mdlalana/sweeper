import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sweeper/features/gallery/data/photo_manager_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';

const _channel = MethodChannel('com.fluttercandies/photo_manager');

/// A fake MediaStore holding a mix of photo and video assets, so
/// [PhotoManagerRepository.getVideoMedia] can be verified to request only
/// video-typed assets (RequestType.video, value 2) while
/// [PhotoManagerRepository.getMedia] keeps requesting only images
/// (RequestType.image, value 1) — the two queries must never bleed into
/// each other's results.
class _FakeMixedMediaStore {
  _FakeMixedMediaStore({required this.photoCount, required this.videoCount});

  final int photoCount;
  final int videoCount;
  final List<int> recordedTypes = [];

  List<Map<String, dynamic>> get _photos => [
        for (var i = 0; i < photoCount; i++)
          <String, dynamic>{
            'id': 'photo$i',
            'type': 1,
            'width': 100,
            'height': 100,
            'createDt': 1000000 + i,
            'duration': 0,
          },
      ];

  List<Map<String, dynamic>> get _videos => [
        for (var i = 0; i < videoCount; i++)
          <String, dynamic>{
            'id': 'video$i',
            'type': 2,
            'width': 100,
            'height': 100,
            'createDt': 2000000 + i,
            'duration': 10 + i, // seconds
          },
      ];

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getAssetPathList':
        final type = (call.arguments as Map)['type'] as int;
        recordedTypes.add(type);
        final count = type == 2 ? videoCount : photoCount;
        return <String, dynamic>{
          'data': [
            {'id': 'all', 'name': 'Recent', 'assetCount': count, 'isAll': true, 'albumType': 1},
          ],
        };
      case 'getAssetCountFromPath':
        final type = (call.arguments as Map)['type'] as int;
        return type == 2 ? videoCount : photoCount;
      case 'getAssetListPaged':
        final args = call.arguments as Map;
        final type = args['type'] as int;
        final page = args['page'] as int;
        final size = args['size'] as int;
        final all = type == 2 ? _videos : _photos;
        final start = (page * size).clamp(0, all.length);
        final end = (start + size).clamp(0, all.length);
        return <String, dynamic>{'data': all.sublist(start, end)};
      case 'getFullFile':
        final id = (call.arguments as Map)['id'] as String;
        return '/tmp/fake/$id.mp4';
      case 'fetchEntityProperties':
        final id = (call.arguments as Map)['id'] as String;
        return [..._photos, ..._videos].firstWhere((a) => a['id'] == id);
      default:
        return null;
    }
  }
}

/// A fake MediaStore holding [count] assets, one per day, with the given
/// ordering honoured natively (i.e. by the query, not by the caller).
///
/// Records the `orders` the repository asked for so the test can assert the
/// ordering is actually pushed down to the platform query.
class _FakeMediaStore {
  _FakeMediaStore(this.count);

  final int count;
  final List<Map> recordedOrders = [];

  /// Asset n has createDt of 1_000_000 + n, so a bigger n is a newer asset.
  List<Map<String, dynamic>> _assets(bool asc) {
    final indices = List.generate(count, (i) => i);
    // Newest-first is the natural MediaStore default; ascending flips it.
    final ordered = asc ? indices : indices.reversed.toList();
    return [
      for (final i in ordered)
        <String, dynamic>{
          'id': 'asset$i',
          'type': 1,
          'width': 100,
          'height': 100,
          'createDt': 1000000 + i,
        },
    ];
  }

  bool _ascFrom(dynamic option) {
    final orders = ((option as Map)['child'] as Map)['orders'] as List;
    recordedOrders.add({'orders': orders});
    if (orders.isEmpty) return false;
    return (orders.first as Map)['asc'] as bool;
  }

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getAssetPathList':
        _ascFrom((call.arguments as Map)['option']);
        return <String, dynamic>{
          'data': [
            {'id': 'all', 'name': 'Recent', 'assetCount': count, 'isAll': true, 'albumType': 1},
          ],
        };
      case 'getAssetCountFromPath':
        return count;
      case 'getAssetListPaged':
        final args = call.arguments as Map;
        final asc = _ascFrom(args['option']);
        final page = args['page'] as int;
        final size = args['size'] as int;
        final all = _assets(asc);
        final start = (page * size).clamp(0, all.length);
        final end = (start + size).clamp(0, all.length);
        return <String, dynamic>{'data': all.sublist(start, end)};
      default:
        return null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sort order is pushed into the native query', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('filterOptionGroupForSort orders by create date ascending only for oldestFirst', () {
      expect(
        filterOptionGroupForSort(SortOrder.oldestFirst).orders,
        [const OrderOption(type: OrderOptionType.createDate, asc: true)],
      );
      expect(
        filterOptionGroupForSort(SortOrder.newestFirst).orders,
        [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      );
    });

    test('oldestFirst paginates in true ascending date order across page boundaries',
        () async {
      final store = _FakeMediaStore(10);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, store.handle);

      final repo = PhotoManagerRepository();
      final page0 =
          await repo.getMedia(page: 0, pageSize: 4, sort: SortOrder.oldestFirst);
      final page1 =
          await repo.getMedia(page: 1, pageSize: 4, sort: SortOrder.oldestFirst);
      final page2 =
          await repo.getMedia(page: 2, pageSize: 4, sort: SortOrder.oldestFirst);

      // Page 0 must be the genuinely oldest assets, not a locally reversed
      // slice of the newest page.
      expect(page0.items.map((i) => i.id).toList(),
          ['asset0', 'asset1', 'asset2', 'asset3']);
      expect(page1.items.map((i) => i.id).toList(),
          ['asset4', 'asset5', 'asset6', 'asset7']);
      expect(page2.items.map((i) => i.id).toList(), ['asset8', 'asset9']);
      expect(page0.hasMore, isTrue);
      expect(page2.hasMore, isFalse);

      // Dates strictly ascend across the page boundaries.
      final dates = [...page0.items, ...page1.items, ...page2.items]
          .map((i) => i.dateTaken)
          .toList();
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isTrue);
      }

      // The ascending order was requested from the platform, not applied after.
      expect(
        store.recordedOrders.every((r) =>
            ((r['orders'] as List).first as Map)['asc'] == true),
        isTrue,
      );
    });

    test('newestFirst paginates in descending date order', () async {
      final store = _FakeMediaStore(10);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, store.handle);

      final repo = PhotoManagerRepository();
      final page0 =
          await repo.getMedia(page: 0, pageSize: 4, sort: SortOrder.newestFirst);

      expect(page0.items.map((i) => i.id).toList(),
          ['asset9', 'asset8', 'asset7', 'asset6']);
    });
  });

  group('video querying', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('getVideoMedia only requests and returns video-typed assets', () async {
      final store = _FakeMixedMediaStore(photoCount: 3, videoCount: 2);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, store.handle);

      final repo = PhotoManagerRepository();
      final page = await repo.getVideoMedia(page: 0, pageSize: 10, sort: SortOrder.newestFirst);

      expect(page.items.map((i) => i.id).toSet(), {'video0', 'video1'});
      expect(page.items.every((i) => i.type == MediaType.video), isTrue);
      expect(store.recordedTypes, everyElement(2));
    });

    test('getVideoMedia maps duration seconds to durationMs', () async {
      final store = _FakeMixedMediaStore(photoCount: 0, videoCount: 1);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, store.handle);

      final repo = PhotoManagerRepository();
      final page = await repo.getVideoMedia(page: 0, pageSize: 10, sort: SortOrder.newestFirst);

      expect(page.items.single.durationMs, 10000);
    });

    test('getMedia (photos) still only requests image-typed assets after the refactor', () async {
      final store = _FakeMixedMediaStore(photoCount: 3, videoCount: 2);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, store.handle);

      final repo = PhotoManagerRepository();
      final page = await repo.getMedia(page: 0, pageSize: 10, sort: SortOrder.newestFirst);

      expect(page.items.map((i) => i.id).toSet(), {'photo0', 'photo1', 'photo2'});
      expect(store.recordedTypes, everyElement(1));
    });

    test('getVideoFile resolves the asset file from photo_manager', () async {
      final store = _FakeMixedMediaStore(photoCount: 0, videoCount: 1);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, store.handle);

      final repo = PhotoManagerRepository();
      final page = await repo.getVideoMedia(page: 0, pageSize: 10, sort: SortOrder.newestFirst);
      final file = await repo.getVideoFile(page.items.single);

      expect(file?.path, '/tmp/fake/video0.mp4');
    });
  });

  test('mapDeleteIdsToResult splits requested ids into deleted vs failed', () {
    final result = mapDeleteIdsToResult(
      requestedIds: ['a', 'b', 'c'],
      deletedIds: ['a', 'c'],
    );

    expect(result.deletedIds, ['a', 'c']);
    expect(result.failedIds, ['b']);
  });
}
