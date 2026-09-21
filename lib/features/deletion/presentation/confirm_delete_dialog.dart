import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

Future<bool?> showConfirmDeleteDialog(BuildContext context, {required int itemCount}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Delete $itemCount items permanently?', style: AppTextStyles.display(size: 22)),
      content: Text(
        "They'll be removed from your device and can't be recovered. "
        'Android may ask you to allow this once more.',
        style: AppTextStyles.bodySecondary(size: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
