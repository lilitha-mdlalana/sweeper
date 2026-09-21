import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PermissionScreen extends StatelessWidget {
  final VoidCallback onAllowPressed;
  final VoidCallback onPrivacyPressed;
  final bool permanentlyDenied;

  const PermissionScreen({
    super.key,
    required this.onAllowPressed,
    required this.onPrivacyPressed,
    this.permanentlyDenied = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('permission-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your photos never leave this phone.',
                  style: AppTextStyles.display(size: 30)),
              const SizedBox(height: 10),
              Text(
                permanentlyDenied
                    ? 'Photo access was denied. Enable it in Android settings to use Sweep.'
                    : 'To show your photos one at a time, Sweep needs access to your gallery. '
                        'Everything is processed on this device.',
                style: AppTextStyles.bodySecondary(size: 15),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onAllowPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    permanentlyDenied ? 'Open Android settings' : 'Allow photo access',
                    style: AppTextStyles.body(size: 16, weight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onPrivacyPressed,
                child: Text('Read the privacy details',
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
