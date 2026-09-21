enum MediaType { photo, video }

class MediaItem {
  final String id;
  final DateTime dateTaken;
  final int sizeBytes;
  final int width;
  final int height;
  final MediaType type;

  MediaItem({
    required this.id,
    required this.dateTaken,
    required this.sizeBytes,
    required this.width,
    required this.height,
    this.type = MediaType.photo,
  });
}
