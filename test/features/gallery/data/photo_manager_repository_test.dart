import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/data/photo_manager_repository.dart';

void main() {
  test('mapDeleteIdsToResult splits requested ids into deleted vs failed', () {
    final result = mapDeleteIdsToResult(
      requestedIds: ['a', 'b', 'c'],
      deletedIds: ['a', 'c'],
    );

    expect(result.deletedIds, ['a', 'c']);
    expect(result.failedIds, ['b']);
  });
}
