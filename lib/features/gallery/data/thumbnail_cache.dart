import 'dart:typed_data';

class ThumbnailCache {
  final int maxEntries;
  final _map = <String, Uint8List>{};

  ThumbnailCache({this.maxEntries = 30});

  Uint8List? get(String id) {
    final value = _map.remove(id);
    if (value == null) return null;
    _map[id] = value; // re-insert to mark as most-recently-used
    return value;
  }

  void put(String id, Uint8List bytes) {
    _map.remove(id);
    _map[id] = bytes;
    if (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  void evict(String id) => _map.remove(id);
}
