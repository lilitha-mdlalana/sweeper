import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _bullets = [
    ('Nothing is uploaded', 'Photos are never sent to a server.'),
    ('No account', 'There is nothing to sign in to.'),
    ('Processed on this device', 'Thumbnails and decisions stay local.'),
    ('You confirm every deletion', 'A swipe only marks a photo.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('privacy-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text('Privacy', style: AppTextStyles.body(size: 20, weight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Text('Stays on your phone.', style: AppTextStyles.display(size: 36)),
                const SizedBox(height: 24),
                for (final bullet in _bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bullet.$1, style: AppTextStyles.body(size: 16, weight: FontWeight.w600)),
                              Text(bullet.$2, style: AppTextStyles.bodySecondary()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.borderMedium),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Why Sweep asks for photo access',
                          style: AppTextStyles.body(size: 16, weight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'Android requires this permission before any app can read your gallery. '
                        'Sweep uses it only to show your photos as cards, and to delete the ones you confirm.',
                        style: AppTextStyles.bodySecondary(size: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: openAppSettings,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Text('Open Android settings', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
