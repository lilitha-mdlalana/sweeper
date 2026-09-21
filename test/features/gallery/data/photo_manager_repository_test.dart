import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sweeper/features/gallery/data/photo_manager_repository.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';

const _channel = MethodChannel('com.fluttercandies/photo_manager');

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

  test('mapDeleteIdsToResult splits requested ids into deleted vs failed', () {
    final result = mapDeleteIdsToResult(
      requestedIds: ['a', 'b', 'c'],
      deletedIds: ['a', 'c'],
    );

    expect(result.deletedIds, ['a', 'c']);
    expect(result.failedIds, ['b']);
  });
}
