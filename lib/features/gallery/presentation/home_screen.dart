import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/gallery_state.dart';
import '../domain/media_item.dart';
import '../domain/swipe_action.dart';
import '../../deletion/presentation/deletion_providers.dart';
import 'done_screen.dart';
import 'gallery_providers.dart';
import 'swipe_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onReviewDeletions;

  const HomeScreen({super.key, required this.onReviewDeletions});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<SwipeAction>? _sub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      _sub = ref.read(galleryProvider.notifier).lastSwipeEvents.listen((action) {
        if (!mounted) return;
        final justActed = ref.read(galleryProvider).value?.lastActedItem;
        if (action == SwipeAction.delete && justActed != null) {
          ref.read(deletionQueueProvider.notifier).add(justActed);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.snackbarBackground,
              duration: const Duration(seconds: 4),
              // Floating + a bottom margin that clears the ~60px action row
              // (plus padding/safe area) so the dedicated Delete/Undo/Keep
              // buttons stay tappable while the snackbar is visible.
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 12, right: 12),
              content: const Text('Photo marked for deletion', style: TextStyle(color: Colors.white)),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppColors.undoLink,
                onPressed: () {
                  ref.read(galleryProvider.notifier).undo();
                  ref.read(deletionQueueProvider.notifier).removeById(justActed.id);
                },
              ),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryAsync = ref.watch(galleryProvider);

    ref.listen(galleryProvider, (previous, next) {
      final error = next.value?.loadError;
      if (error == null || error == previous?.value?.loadError) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('load-error-snackbar'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 12, right: 12),
          content: Text(error),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () => ref.invalidate(galleryProvider),
          ),
        ),
      );
    });

    return Scaffold(
      key: const Key('home-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: galleryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load photos: $e')),
          data: (state) {
            if (state.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No photos to clean. Your gallery is empty.'),
                ),
              );
            }
            if (state.isDone) {
              return DoneScreen(
                totalReviewed: state.totalReviewed,
                totalMarkedForDeletion: state.totalMarkedForDeletion,
                onReviewDeletions: widget.onReviewDeletions,
                onStartAgain: () => ref.invalidate(galleryProvider),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clean your gallery', style: AppTextStyles.bodySecondary()),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${state.remaining}', style: AppTextStyles.display(size: 40)),
                              const SizedBox(width: 8),
                              Text('remaining',
                                  style: AppTextStyles.body(size: 16, weight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                      Text('${state.totalMarkedForDeletion} to delete',
                          style: AppTextStyles.body(
                              size: 14, weight: FontWeight.w600, color: AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: state.queue.isEmpty
                          ? 0
                          : state.totalReviewed / state.queue.length,
                      minHeight: 4,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _CardStack(state: state, ref: ref)),
                  const SizedBox(height: 20),
                  _ActionRow(ref: ref),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardStack extends StatelessWidget {
  final GalleryState state;
  final WidgetRef ref;
  const _CardStack({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final upcoming = <MediaItem>[
      for (var i = state.currentIndex; i < state.queue.length && i < state.currentIndex + 3; i++)
        state.queue[i],
    ];
    if (upcoming.isEmpty) {
      // The queue is momentarily drained while the next page loads. Show a
      // spinner rather than a blank, inert card area.
      return const Center(
        key: Key('card-stack-loading'),
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = upcoming.length - 1; i >= 0; i--)
          if (i == 0)
            SwipeCard(
              key: ValueKey(upcoming[0].id),
              onSwiped: (action) => ref.read(galleryProvider.notifier).swipe(action),
              child: _MediaCard(item: upcoming[0], isCurrent: true),
            )
          else
            Transform.translate(
              offset: Offset(0, i * 8.0),
              child: Opacity(
                opacity: 1 - (i * 0.15),
                child: _MediaCard(item: upcoming[i]),
              ),
            ),
      ],
    );
  }
}

/// Auto-skips a card whose thumbnail resolved to null, but only while that
/// exact card is still the front card.
///
/// The skip runs in a microtask queued during build, so by the time it fires
/// the user may already have swiped this card away; without this guard the
/// skip would land on the next, perfectly good photo.
void autoSkipIfStillCurrent({
  required GalleryState? state,
  required MediaItem item,
  required VoidCallback skip,
}) {
  if (state?.currentItem?.id != item.id) return;
  skip();
}

class _MediaCard extends ConsumerWidget {
  final MediaItem item;
  final bool isCurrent;
  const _MediaCard({required this.item, this.isCurrent = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(mediaRepositoryProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: AppColors.chipBackground,
        child: FutureBuilder<Uint8List?>(
          future: repo.getThumbnail(item),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data == null) {
              if (isCurrent) {
                Future.microtask(() => autoSkipIfStillCurrent(
                      state: ref.read(galleryProvider).value,
                      item: item,
                      skip: () =>
                          ref.read(galleryProvider.notifier).swipe(SwipeAction.skip),
                    ));
              }
              return const Center(
                child: Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary),
              );
            }
            return Image.memory(snapshot.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
          },
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final WidgetRef ref;
  const _ActionRow({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundButton(
          label: 'Delete',
          icon: Icons.close,
          background: AppColors.accent,
          foreground: Colors.white,
          onTap: () => ref.read(galleryProvider.notifier).swipe(SwipeAction.delete),
        ),
        IconButton(
          onPressed: () {
            final lastItem = ref.read(galleryProvider).value?.lastActedItem;
            final lastAction = ref.read(galleryProvider).value?.lastAction;
            ref.read(galleryProvider.notifier).undo();
            if (lastAction == SwipeAction.delete && lastItem != null) {
              ref.read(deletionQueueProvider.notifier).removeById(lastItem.id);
            }
          },
          icon: const Icon(Icons.undo),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.borderStrong),
          ),
        ),
        _RoundButton(
          label: 'Keep',
          icon: Icons.check,
          background: AppColors.textPrimary,
          foreground: Colors.white,
          onTap: () => ref.read(galleryProvider.notifier).swipe(SwipeAction.keep),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _RoundButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: foreground),
        label: Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}
