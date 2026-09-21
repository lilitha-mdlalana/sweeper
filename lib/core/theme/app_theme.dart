import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        textTheme: TextTheme(
          headlineLarge: AppTextStyles.display(size: 34),
          headlineMedium: AppTextStyles.display(size: 28),
          bodyMedium: AppTextStyles.body(),
          bodySmall: AppTextStyles.bodySecondary(),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      );
}
