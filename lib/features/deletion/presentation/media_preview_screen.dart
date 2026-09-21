import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../gallery/domain/media_item.dart';
import '../../gallery/presentation/gallery_providers.dart';

class MediaPreviewScreen extends ConsumerWidget {
  final MediaItem item;
  const MediaPreviewScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(mediaRepositoryProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: FutureBuilder<Uint8List?>(
          future: repo.getOriginalBytes(item),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            if (snapshot.data == null) {
              return const Text('Could not load this photo.', style: TextStyle(color: Colors.white));
            }
            return InteractiveViewer(child: Image.memory(snapshot.data!));
          },
        ),
      ),
    );
  }
}
