import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/data/thumbnail_cache.dart';

void main() {
  test('put/get round-trips and evict removes an entry', () {
    final cache = ThumbnailCache(maxEntries: 2);
    final bytes = Uint8List.fromList([1, 2, 3]);

    cache.put('a', bytes);
    expect(cache.get('a'), bytes);

    cache.evict('a');
    expect(cache.get('a'), isNull);
  });

  test('overflow evicts the least-recently-used entry', () {
    final cache = ThumbnailCache(maxEntries: 2);
    cache.put('a', Uint8List.fromList([1]));
    cache.put('b', Uint8List.fromList([2]));
    cache.get('a'); // touch a, making b the LRU
    cache.put('c', Uint8List.fromList([3])); // should evict b

    expect(cache.get('a'), isNotNull);
    expect(cache.get('b'), isNull);
    expect(cache.get('c'), isNotNull);
  });
}
