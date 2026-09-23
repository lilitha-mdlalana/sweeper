import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/format_bytes.dart';

class VideoEndScreen extends StatelessWidget {
  final int totalReviewed;
  final int totalMarkedForDeletion;
  final int storageToReclaimBytes;
  final VoidCallback onReviewDeletions;
  final VoidCallback onDone;

  const VideoEndScreen({
    super.key,
    required this.totalReviewed,
    required this.totalMarkedForDeletion,
    required this.storageToReclaimBytes,
    required this.onReviewDeletions,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isCaughtUp = totalReviewed == 0 && totalMarkedForDeletion == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text('$totalReviewed', style: AppTextStyles.display(size: 52)),
          Text('videos reviewed', style: AppTextStyles.bodySecondary()),
          const SizedBox(height: 16),
          Text(
            isCaughtUp ? "You're all caught up." : "You've reviewed all your videos.",
            style: AppTextStyles.display(size: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isCaughtUp
                ? 'No more videos to review.'
                : '$totalMarkedForDeletion marked for deletion · ${formatBytes(storageToReclaimBytes)} ready to reclaim',
            style: AppTextStyles.bodySecondary(size: 17),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onReviewDeletions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text('Review Deletions',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onDone,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderStrong),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
