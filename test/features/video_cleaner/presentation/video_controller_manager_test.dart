import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/video_cleaner/presentation/video_controller_manager.dart';

MediaItem _video(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
      type: MediaType.video,
    );

void main() {
  group('neighborIds', () {
    test('at the start of the list: current and next only, no previous', () {
      final items = [_video('a'), _video('b'), _video('c')];
      expect(neighborIds(items, 0), ['a', 'b']);
    });

    test('in the middle: previous, current, next', () {
      final items = [_video('a'), _video('b'), _video('c')];
      expect(neighborIds(items, 1), ['a', 'b', 'c']);
    });

    test('at the end of the list: previous and current only, no next', () {
      final items = [_video('a'), _video('b'), _video('c')];
      expect(neighborIds(items, 2), ['b', 'c']);
    });

    test('single-item list: just current', () {
      final items = [_video('a')];
      expect(neighborIds(items, 0), ['a']);
    });
  });
}
