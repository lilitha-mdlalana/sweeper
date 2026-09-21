import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

void main() {
  test('MediaItem defaults to MediaType.photo', () {
    final item = MediaItem(
      id: 'abc',
      dateTaken: DateTime(2024, 3, 14),
      sizeBytes: 3200000,
      width: 1080,
      height: 1920,
    );
    expect(item.type, MediaType.photo);
    expect(item.id, 'abc');
  });
}
