import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/gallery_state.dart';
import '../domain/media_item.dart';
import '../domain/swipe_action.dart';
import 'gallery_providers.dart';
import 'swipe_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<SwipeAction>? _sub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _sub = ref.read(galleryProvider.notifier).lastSwipeEvents.listen((action) {
        if (action == SwipeAction.delete) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.snackbarBackground,
              duration: const Duration(seconds: 4),
              content: const Text('Photo marked for deletion', style: TextStyle(color: Colors.white)),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppColors.undoLink,
                onPressed: () => ref.read(galleryProvider.notifier).undo(),
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

    return Scaffold(
      key: const Key('home-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: galleryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load photos: $e')),
          data: (state) {
            if (state.isDone) {
              return const Center(child: Text("You're done."));
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
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = upcoming.length - 1; i >= 0; i--)
          if (i == 0)
            SwipeCard(
              key: ValueKey(upcoming[0].id),
              onSwiped: (action) => ref.read(galleryProvider.notifier).swipe(action),
              child: _MediaCard(item: upcoming[0]),
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

class _MediaCard extends ConsumerWidget {
  final MediaItem item;
  const _MediaCard({required this.item});

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
          onPressed: () => ref.read(galleryProvider.notifier).undo(),
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
