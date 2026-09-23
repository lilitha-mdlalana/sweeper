import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/format_bytes.dart';
import '../../gallery/domain/media_item.dart';
import '../../gallery/domain/media_repository.dart';
import '../../gallery/presentation/gallery_providers.dart';

const int kLargeFileThresholdBytes = 500 * 1024 * 1024; // 500 MB
const double kDeleteSwipeThreshold = 100;

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatDate(DateTime d) => '${d.day} ${_monthName(d.month)} ${d.year}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
String _monthName(int month) => _months[month - 1];

class VideoPagerItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final VideoPlayerController? controller;
  final VoidCallback onDelete;
  final VoidCallback onKeep;

  const VideoPagerItem({
    super.key,
    required this.item,
    required this.controller,
    required this.onDelete,
    required this.onKeep,
  });

  @override
  ConsumerState<VideoPagerItem> createState() => _VideoPagerItemState();
}

class _VideoPagerItemState extends ConsumerState<VideoPagerItem> {
  double _dragDx = 0;
  bool _dragging = false;
  bool _showPlayPauseGlyph = false;

  static const _deadZone = 8.0;

  void _onTap() {
    final controller = widget.controller;
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      _showPlayPauseGlyph = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showPlayPauseGlyph = false);
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final candidate = _dragDx + details.delta.dx;
    // Ignore tiny jitter below the dead zone so an intended tap never reads
    // as the start of a drag.
    if (!_dragging && candidate.abs() < _deadZone) return;
    setState(() {
      _dragging = true;
      _dragDx = candidate;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final dx = _dragDx;
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
    if (dx <= -kDeleteSwipeThreshold) {
      HapticFeedback.mediumImpact();
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(mediaRepositoryProvider);
    final controller = widget.controller;
    final effectiveDx = _dragging ? _dragDx.clamp(-double.infinity, 0.0) : 0.0;
    final deleteOpacity = (-effectiveDx / kDeleteSwipeThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: _onTap,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Transform.translate(
            offset: Offset(effectiveDx, 0),
            child: Center(
              child: controller != null && controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    )
                  : _PosterFallback(repo: repo, item: widget.item),
            ),
          ),
          if (deleteOpacity > 0)
            Positioned(
              left: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: deleteOpacity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.arrow_back, color: Colors.white),
                      SizedBox(width: 6),
                      Text('DELETE',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
          if (_showPlayPauseGlyph)
            Center(
              child: Icon(
                controller != null && controller.value.isPlaying
                    ? Icons.play_arrow
                    : Icons.pause,
                color: Colors.white70,
                size: 72,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomInfo(item: widget.item, controller: controller),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 100,
            child: _ActionRow(onDelete: widget.onDelete, onKeep: widget.onKeep),
          ),
        ],
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final MediaRepository repo;
  final MediaItem item;
  const _PosterFallback({required this.repo, required this.item});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: repo.getThumbnail(item),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.data == null) {
          return const Center(
            child: Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
          );
        }
        return Image.memory(snapshot.data!, fit: BoxFit.contain);
      },
    );
  }
}

class _BottomInfo extends StatelessWidget {
  final MediaItem item;
  final VideoPlayerController? controller;
  const _BottomInfo({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isLarge = item.sizeBytes > kLargeFileThresholdBytes;
    final duration = controller?.value.isInitialized == true
        ? controller!.value.duration
        : Duration(milliseconds: item.durationMs);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller != null && controller!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: duration.inMilliseconds == 0
                    ? 0
                    : controller!.value.position.inMilliseconds / duration.inMilliseconds,
                minHeight: 2,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.play_arrow, color: Colors.white, size: 16),
              Text(_formatDuration(duration),
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatBytes(item.sizeBytes),
            style: AppTextStyles.body(
              size: 16,
              weight: FontWeight.w700,
              color: isLarge ? AppColors.undoLink : Colors.white,
            ),
          ),
          Text(_formatDate(item.dateTaken),
              style: AppTextStyles.body(size: 13, weight: FontWeight.w500, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onKeep;
  const _ActionRow({required this.onDelete, required this.onKeep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
        Column(
          children: const [
            Icon(Icons.keyboard_arrow_up, color: Colors.white70),
            Text('Next', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: onKeep,
          icon: const Icon(Icons.check, color: Colors.black),
          label: const Text('Keep', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ],
    );
  }
}
