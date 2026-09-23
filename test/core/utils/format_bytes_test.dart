import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/core/utils/format_bytes.dart';

void main() {
  test('formats bytes under 1KB', () {
    expect(formatBytes(500), '500 B');
  });

  test('formats kilobytes with one decimal', () {
    expect(formatBytes(2048), '2.0 KB');
  });

  test('formats megabytes with one decimal', () {
    expect(formatBytes(25 * 1024 * 1024), '25.0 MB');
  });

  test('formats gigabytes with one decimal', () {
    final oneGb = 1024 * 1024 * 1024;
    expect(formatBytes((1.8 * oneGb).round()), '1.8 GB');
  });

  test('formats zero bytes', () {
    expect(formatBytes(0), '0 B');
  });
}
