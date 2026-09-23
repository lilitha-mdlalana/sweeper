import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/format_bytes.dart';
import '../../gallery/presentation/gallery_providers.dart';
import '../domain/video_queue_state.dart';
import 'video_cleaner_providers.dart';
import 'video_controller_manager.dart';
import 'video_end_screen.dart';
import 'video_pager_item.dart';

class VideoCleanerScreen extends ConsumerStatefulWidget {
  final VoidCallback onReviewDeletions;

  const VideoCleanerScreen({super.key, required this.onReviewDeletions});

  @override
  ConsumerState<VideoCleanerScreen> createState() => _VideoCleanerScreenState();
}

class _VideoCleanerScreenState extends ConsumerState<VideoCleanerScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late final VideoControllerManager _controllerManager;
  int? _lastHandledPageIndex;
  bool _wasAtEnd = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controllerManager = VideoControllerManager(ref.read(mediaRepositoryProvider));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused) {
      final current = ref.read(videoQueueProvider).value?.currentItem;
      if (current != null) {
        _controllerManager.controllerFor(current.id)?.pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _controllerManager.disposeAll();
    super.dispose();
  }

  Future<void> _handlePageSettled(VideoQueueState state) async {
    if (_lastHandledPageIndex == state.currentPageIndex) return;
    _lastHandledPageIndex = state.currentPageIndex;

    for (final id in _controllerManager.cachedIds) {
      if (id != state.currentItem?.id) {
        _controllerManager.controllerFor(id)?.pause();
      }
    }
    await _controllerManager.preloadNeighbors(state.items, state.currentPageIndex);
    final current = state.currentItem;
    if (current != null) {
      await _controllerManager.controllerFor(current.id)?.play();
    }
    if (mounted) setState(() {});

    if (state.isAtEnd && !_wasAtEnd) {
      HapticFeedback.mediumImpact();
    }
    _wasAtEnd = state.isAtEnd;
  }

  void _decideAndAdvance(VideoDecision decision) {
    final state = ref.read(videoQueueProvider).value;
    final current = state?.currentItem;
    if (current == null) return;

    decision == VideoDecision.delete
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.lightImpact();
    ref.read(videoQueueProvider.notifier).decide(current.id, decision);

    if (decision == VideoDecision.delete && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.snackbarBackground,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          // Clears VideoPagerItem's Delete/Keep row (positioned at bottom: 100
          // with its own height) so both buttons stay tappable while it's up.
          margin: const EdgeInsets.only(bottom: 170, left: 12, right: 12),
          content: const Text('Video marked for deletion', style: TextStyle(color: Colors.white)),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.undoLink,
            onPressed: () => ref.read(videoQueueProvider.notifier).undo(),
          ),
        ),
      );
    }

    if (_pageController.hasClients && state!.currentPageIndex < state.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoQueueProvider);

    ref.listen(videoQueueProvider, (previous, next) {
      final state = next.value;
      if (state == null) return;
      _handlePageSettled(state);
    });

    return Scaffold(
      key: const Key('video-cleaner-screen'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: videoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => Center(
            child: Text('Could not load videos: $e', style: const TextStyle(color: Colors.white)),
          ),
          data: (state) {
            if (state.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No videos to clean. Your video library is already empty.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (state.isSessionComplete) {
              return VideoEndScreen(
                totalReviewed: state.reviewedCount,
                totalMarkedForDeletion: state.markedForDeletionCount,
                storageToReclaimBytes: state.storageToReclaimBytes,
                onReviewDeletions: widget.onReviewDeletions,
                onDone: () => Navigator.of(context).pop(),
              );
            }
            return Column(
              children: [
                _Header(state: state),
                Expanded(
                  child: PageView.builder(
                    key: const Key('video-pager'),
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: state.items.length,
                    onPageChanged: (index) =>
                        ref.read(videoQueueProvider.notifier).setCurrentPage(index),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return VideoPagerItem(
                        key: ValueKey(item.id),
                        item: item,
                        controller: _controllerManager.controllerFor(item.id),
                        onDelete: () => _decideAndAdvance(VideoDecision.delete),
                        onKeep: () => _decideAndAdvance(VideoDecision.keep),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VideoQueueState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Videos  ${state.currentPageIndex + 1}/${state.totalCount}',
            style: AppTextStyles.body(size: 16, weight: FontWeight.w700, color: Colors.white),
          ),
          Row(
            children: [
              const Icon(Icons.delete_outline, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${state.markedForDeletionCount} marked',
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: Colors.white70)),
              const SizedBox(width: 10),
              const Icon(Icons.save_outlined, size: 16, color: AppColors.undoLink),
              const SizedBox(width: 4),
              Text(formatBytes(state.storageToReclaimBytes),
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: AppColors.undoLink)),
            ],
          ),
        ],
      ),
    );
  }
}
