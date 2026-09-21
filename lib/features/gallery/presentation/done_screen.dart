import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class DoneScreen extends StatelessWidget {
  final int totalReviewed;
  final int totalMarkedForDeletion;
  final VoidCallback onReviewDeletions;
  final VoidCallback onStartAgain;

  const DoneScreen({
    super.key,
    required this.totalReviewed,
    required this.totalMarkedForDeletion,
    required this.onReviewDeletions,
    required this.onStartAgain,
  });

  @override
  Widget build(BuildContext context) {
    final kept = totalReviewed - totalMarkedForDeletion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text('$totalReviewed', style: AppTextStyles.display(size: 52)),
          Text('photos', style: AppTextStyles.bodySecondary()),
          const SizedBox(height: 16),
          Text("You're done.", style: AppTextStyles.display(size: 36)),
          const SizedBox(height: 6),
          Text('You reviewed $totalReviewed photos.', style: AppTextStyles.bodySecondary(size: 17)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              _Pill(color: AppColors.textPrimary, label: '$kept kept'),
              _Pill(color: AppColors.accent, label: '$totalMarkedForDeletion marked for deletion'),
            ],
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
              child: const Text('Review deletions',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onStartAgain,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderStrong),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: const Text('Start again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Color color;
  final String label;
  const _Pill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.body(size: 14, weight: FontWeight.w500)),
      ]),
    );
  }
}
